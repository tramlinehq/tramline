# == Schema Information
#
# Table name: integrations
#
#  id              :uuid             not null, primary key
#  category        :string           not null, indexed => [integrable_id, providable_type, status]
#  discarded_at    :datetime
#  integrable_type :string
#  metadata        :jsonb
#  providable_type :string           indexed => [integrable_id, category, status]
#  status          :string           indexed => [integrable_id, category, providable_type]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  integrable_id   :uuid             indexed => [category, providable_type, status]
#  providable_id   :uuid
#
class Integration < ApplicationRecord
  has_paper_trail
  using RefinedArray
  using RefinedString
  include Discard::Model
  include Loggable

  self.ignored_columns += %w[app_id]

  belongs_to :app, optional: true

  PROVIDER_TYPES = %w[GithubIntegration GitlabIntegration SlackIntegration AppStoreIntegration GooglePlayStoreIntegration BitriseIntegration GoogleFirebaseIntegration BugsnagIntegration BitbucketIntegration CrashlyticsIntegration JiraIntegration LinearIntegration SentryIntegration]
  delegated_type :providable, types: PROVIDER_TYPES, autosave: true, validate: false
  delegated_type :integrable, types: INTEGRABLE_TYPES, autosave: true, validate: false

  IntegrationNotImplemented = Class.new(StandardError)
  UnsupportedAction = Class.new(StandardError)

  APP_VARIANT_PROVIDABLE_TYPES = %w[GoogleFirebaseIntegration]

  ALLOWED_INTEGRATIONS_FOR_APP = {
    ios: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration GitlabIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[AppStoreIntegration GoogleFirebaseIntegration],
      "monitoring" => %w[BugsnagIntegration CrashlyticsIntegration SentryIntegration],
      "project_management" => %w[JiraIntegration LinearIntegration]
    },
    android: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration GitlabIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration GoogleFirebaseIntegration],
      "monitoring" => %w[BugsnagIntegration CrashlyticsIntegration SentryIntegration],
      "project_management" => %w[JiraIntegration LinearIntegration]
    },
    cross_platform: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration GitlabIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration GoogleFirebaseIntegration AppStoreIntegration],
      "monitoring" => %w[BugsnagIntegration CrashlyticsIntegration SentryIntegration],
      "project_management" => %w[JiraIntegration LinearIntegration]
    }
  }.with_indifferent_access

  INTEGRATIONS_TO_PRE_PROD_SUBMISSIONS = {
    android: {
      GoogleFirebaseIntegration => GoogleFirebaseSubmission,
      GooglePlayStoreIntegration => PlayStoreSubmission
    },
    ios: {
      GoogleFirebaseIntegration => GoogleFirebaseSubmission,
      AppStoreIntegration => TestFlightSubmission
    }
  }.freeze

  enum :category, ALLOWED_INTEGRATIONS_FOR_APP.values.map(&:keys).flatten.uniq.zip_map_self
  enum :status, {connected: "connected", disconnected: "disconnected", needs_reauth: "needs_reauth"}

  CATEGORY_DESCRIPTIONS = {
    version_control: "Automatically create release branches and tags, and merge release PRs.",
    ci_cd: "Trigger workflows to create builds and stay up-to-date as they're made available.",
    notification: "Send release activity notifications at the right time, to the right people.",
    build_channel: "Send builds to the right deployment service for the right stakeholders.",
    monitoring: "Monitor release metrics and stability to make the correct decisions about your release progress.",
    project_management: "Track tickets and establish release readiness by associating tickets with your releases."
  }.freeze
  MULTI_INTEGRATION_CATEGORIES = ["build_channel"].freeze
  MINIMUM_REQUIRED_SET = [:version_control, :ci_cd, :build_channel].freeze
  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected].freeze
  DEFAULT_INITIAL_STATUS = Integration.statuses[:disconnected].freeze
  DISABLED_CATEGORIES = [].freeze

  validate :allowed_integrations_for_app, on: :create
  validate :validate_providable, on: :create
  validate :app_variant_restriction, on: :create
  validates :category, presence: true
  validates :providable_type, uniqueness: {scope: [:integrable_id, :category, :status], message: :unique_connected_integration_category, if: -> { integrable_id.present? && (connected? || needs_reauth?) }}

  attr_accessor :current_user, :code

  delegate :install_path, :connection_data, :project_link, :public_icon_img, to: :providable
  delegate :platform, to: :integrable

  scope :ready, -> { where(category: MINIMUM_REQUIRED_SET, status: :connected) }
  scope :linked, -> { where(status: [:connected, :needs_reauth]) }

  before_create :set_connected
  after_create_commit -> { IntegrationMetadataJob.perform_async(id) }

  class << self
    def by_categories_for(app)
      existing_integrations = app.integrations.linked.includes(:providable)
      integrations = ALLOWED_INTEGRATIONS_FOR_APP[app.platform]

      integrations.each_with_object({}) do |(category, providers), combination|
        next if DISABLED_CATEGORIES.include?(category)

        existing_integration = existing_integrations.select { |integration| integration.category.eql?(category) }
        combination[category] ||= []

        existing_integration.each do |integration|
          combination[category] << integration
        end

        next if MULTI_INTEGRATION_CATEGORIES.exclude?(category) && combination[category].present?

        (providers - existing_integration.pluck(:providable_type)).each do |provider|
          # NOTE: Slack is deprecated as a build channel and will be removed in the future.
          # Do not allow any new Slack integrations as build channels.
          next if category == "build_channel" && provider == "SlackIntegration"

          integration =
            app
              .integrations
              .new(category: categories[category], providable: provider.constantize.new, status: DEFAULT_INITIAL_STATUS)

          combination[category] << integration
        end

        combination
      end
    end

    def find_build_channels(id, with_production: false)
      find_by(id: id).providable.build_channels(with_production:)
    end

    def category_ready?(category)
      app = ready.first&.app

      # if it's not a build channel or single-platform, any of the platforms need to be ready
      if category != :build_channel || !app&.cross_platform?
        return ready.any? { |i| i.category.eql?(category.to_s) }
      end

      # if it's a build channel and cross-platform, both platforms need to be ready
      [:ios, :android].all? do |platform|
        ready
          .build_channel
          .pluck(:providable_type)
          .any? { |type| type.in? ALLOWED_INTEGRATIONS_FOR_APP[platform][:build_channel] }
      end
    end

    def ready?
      MINIMUM_REQUIRED_SET.all? { |category| category_ready?(category) }
    end

    def configured?
      return false if none? # need at least one integration

      further_setup_by_category
        .values
        .pluck(:ready)
        .all?
    end

    def slack_notifications?
      kept.notification.first&.slack_integration?
    end

    def vcs_provider
      kept.version_control.first&.providable
    end

    def ci_cd_provider
      kept.ci_cd.first&.providable
    end

    def bitrise_ci_cd_provider
      kept.ci_cd.find(&:bitrise_integration?)&.providable
    end

    def monitoring_provider
      kept.monitoring.first&.providable
    end

    def notification_provider
      kept.notification.first&.providable
    end

    def android_store_provider
      kept.build_channel.find(&:google_play_store_integration?)&.providable
    end

    def ios_store_provider
      kept.build_channel.find(&:app_store_integration?)&.providable
    end

    def slack_build_channel_provider
      kept.build_channel.find(&:slack_integration?)&.providable
    end

    def firebase_build_channel_provider
      kept.build_channel.find(&:google_firebase_integration?)&.providable
    end

    def project_management_provider
      kept.project_management.first&.providable
    end

    def existing_integrations_across_apps(app, providable_type)
      Integration.connected
        .where(integrable_id: app.organization.apps, providable_type: providable_type)
        .select("DISTINCT ON (metadata) *")
    end

    def build_channels_for_platform(platform)
      kept.build_channel.filter { |b| ALLOWED_INTEGRATIONS_FOR_APP[platform.to_sym][:build_channel].include?(b.providable_type) }
    end

    def further_setup_by_category
      connected_integrations = connected
      categories = {}.with_indifferent_access

      if connected_integrations.version_control.present?
        categories[:version_control] = {
          further_setup: connected_integrations.version_control.any?(&:further_setup?),
          ready: code_repository.present?
        }
      end

      if connected_integrations.ci_cd.present?
        categories[:ci_cd] = {
          further_setup: connected_integrations.ci_cd.any?(&:further_setup?),
          ready: ci_cd_ready?
        }
      end

      if connected_integrations.build_channel.present?
        categories[:build_channel] = {
          further_setup: connected_integrations.build_channel.map(&:providable).any?(&:further_setup?),
          ready: firebase_ready?
        }
      end

      if connected_integrations.monitoring.present?
        categories[:monitoring] = {
          further_setup: connected_integrations.monitoring.any?(&:further_setup?),
          ready: bugsnag_ready?
        }
      end

      if connected_integrations.project_management.present?
        categories[:project_management] = {
          further_setup: connected_integrations.project_management.map(&:providable).any?(&:further_setup?),
          ready: project_management_ready?
        }
      end

      categories
    end

    private

    def providable_error_message(meta)
      meta[:value].errors.full_messages[0]
    end

    def code_repository
      vcs_provider&.repository_config
    end

    def ci_cd_code_repository
      ci_cd_provider&.repository_config
    end

    def ci_cd_ready?
      return false if ci_cd_provider.blank?

      case ci_cd_provider
      when GithubIntegration, GitlabIntegration, BitbucketIntegration
        ci_cd_code_repository.present?
      when BitriseIntegration
        bitrise_ready?
      else
        false
      end
    end

    def bitrise_ready?
      app = first.integrable
      return true unless app.bitrise_connected?
      bitrise_ci_cd_provider&.project.present?
    end

    def firebase_ready?
      app = first.integrable
      return true unless app.firebase_connected?

      firebase_build_channel = firebase_build_channel_provider
      configs_ready?(app, firebase_build_channel&.android_config, firebase_build_channel&.ios_config)
    end

    def bugsnag_ready?
      app = first.integrable
      return true unless app.bugsnag_connected?

      monitoring = monitoring_provider
      configs_ready?(app, monitoring&.android_config, monitoring&.ios_config)
    end

    def project_management_ready?
      return false if project_management.blank?

      jira = project_management.find(&:jira_integration?)&.providable
      linear = project_management.find(&:linear_integration?)&.providable

      if jira
        return jira.project_config.present? &&
            jira.project_config["selected_projects"].present? &&
            jira.project_config["selected_projects"].any? &&
            jira.project_config["project_configs"].present?
      end

      if linear
        return linear.project_config.present? &&
            linear.project_config["selected_teams"].present? &&
            linear.project_config["selected_teams"].any? &&
            linear.project_config["team_configs"].present?
      end

      false
    end

    def configs_ready?(app, android_config, ios_config)
      return ios_config.present? if app.ios?
      return android_config.present? if app.android?
      ios_config.present? && android_config.present? if app.cross_platform?
    end
  end

  def disconnectable?
    app.active_runs.none?
  end

  def disconnectable_categories?
    ci_cd? || version_control?
  end

  def disconnect
    return unless disconnectable?

    transaction do
      update!(status: :disconnected, discarded_at: Time.current)
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  def mark_needs_reauth!
    return unless connected?

    transaction do
      update!(status: :needs_reauth)
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    elog(e, level: :error)
    false
  end

  def set_metadata!
    self.metadata = providable.metadata
    save!
  end

  def further_setup?
    return unless connected?

    return true if version_control?
    return false if notification?
    providable.further_setup?
  end

  def installation_state
    {
      organization_id: integrable.organization.id,
      app_id: integrable.app_id,
      integration_category: category,
      integration_provider: providable_type,
      integration_id: id,
      user_id: current_user.id
    }.to_json.encode
  end

  def set_connected
    self.status = DEFAULT_CONNECT_STATUS
  end

  def store?
    build_channel? && providable.store?
  end

  def controllable_rollout?
    build_channel? && providable.controllable_rollout?
  end

  def allowed_integrations_for_app
    unless providable_type&.in?(ALLOWED_INTEGRATIONS_FOR_APP[platform][category])
      errors.add(:providable_type, "Provider is not allowed for app type: #{platform}")
    end
  end

  def validate_providable
    if providable && !providable.valid?
      errors.add(:base, providable&.errors&.full_messages&.[](0))
    end
  end

  def app_variant_restriction
    return unless integrable_type == "AppVariant"

    if category != Integration.categories[:build_channel]
      errors.add(:category, "must be 'build_channel' when integrable is an AppVariant")
    end

    if APP_VARIANT_PROVIDABLE_TYPES.exclude?(providable_type)
      errors.add(:providable_type, :not_allowed_for_app_variant)
    end
  end
end
