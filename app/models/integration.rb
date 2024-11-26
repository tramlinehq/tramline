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
#  app_id          :uuid             indexed
#  integrable_id   :uuid             indexed => [category, providable_type, status]
#  providable_id   :uuid
#
class Integration < ApplicationRecord
  has_paper_trail
  using RefinedArray
  using RefinedString
  include Discard::Model

  # self.ignored_columns += %w[app_id]
  belongs_to :app, optional: true

  PROVIDER_TYPES = %w[GithubIntegration GitlabIntegration SlackIntegration AppStoreIntegration GooglePlayStoreIntegration BitriseIntegration GoogleFirebaseIntegration BugsnagIntegration BitbucketIntegration]
  delegated_type :providable, types: PROVIDER_TYPES, autosave: true, validate: false
  delegated_type :integrable, types: INTEGRABLE_TYPES, autosave: true, validate: false

  IntegrationNotImplemented = Class.new(StandardError)
  UnsupportedAction = Class.new(StandardError)

  APP_VARIANT_PROVIDABLE_TYPES = %w[GoogleFirebaseIntegration]

  ALLOWED_INTEGRATIONS_FOR_APP = {
    ios: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[AppStoreIntegration GoogleFirebaseIntegration],
      "monitoring" => %w[BugsnagIntegration]
    },
    android: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration GoogleFirebaseIntegration],
      "monitoring" => %w[BugsnagIntegration]
    },
    cross_platform: {
      "version_control" => %w[GithubIntegration GitlabIntegration BitbucketIntegration],
      "ci_cd" => %w[BitriseIntegration GithubIntegration BitbucketIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration GoogleFirebaseIntegration AppStoreIntegration],
      "monitoring" => %w[BugsnagIntegration]
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
  enum :status, {connected: "connected", disconnected: "disconnected"}

  CATEGORY_DESCRIPTIONS = {
    version_control: "Automatically create release branches and tags, and merge release PRs.",
    ci_cd: "Trigger workflows to create builds and stay up-to-date as they're made available.",
    notification: "Send release activity notifications at the right time, to the right people.",
    build_channel: "Send builds to the right deployment service for the right stakeholders.",
    monitoring: "Monitor release metrics and stability to make the correct decisions about your release progress."
  }.freeze
  MULTI_INTEGRATION_CATEGORIES = ["build_channel"].freeze
  MINIMUM_REQUIRED_SET = [:version_control, :ci_cd, :build_channel].freeze
  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected].freeze
  DEFAULT_INITIAL_STATUS = Integration.statuses[:disconnected].freeze

  # FIXME: Can we make a better External Deployment abstraction?
  EXTERNAL_BUILD_INTEGRATION = {
    build_integration: ["None (outside Tramline)", nil],
    build_channels: [{id: :external, name: "External"}]
  }

  validate :allowed_integrations_for_app, on: :create
  validate :validate_providable, on: :create
  validate :app_variant_restriction, on: :create
  validates :category, presence: true
  validates :providable_type, uniqueness: {scope: [:integrable_id, :category, :status], message: :unique_connected_integration_category, if: -> { integrable_id.present? && connected? }}

  attr_accessor :current_user, :code

  delegate :install_path, :connection_data, :project_link, :public_icon_img, to: :providable
  delegate :platform, to: :integrable

  scope :ready, -> { where(category: MINIMUM_REQUIRED_SET, status: :connected) }

  before_create :set_connected
  after_create_commit -> { IntegrationMetadataJob.perform_later(id) }

  class << self
    def by_categories_for(app)
      existing_integrations = app.integrations.connected.includes(:providable)
      integrations = ALLOWED_INTEGRATIONS_FOR_APP[app.platform]

      integrations.each_with_object({}) do |(category, providers), combination|
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
      return EXTERNAL_BUILD_INTEGRATION[:build_channels] if id.blank?
      find_by(id: id).providable.build_channels(with_production:)
    end

    def category_ready?(category)
      app = ready.first&.app

      if category != :build_channel || !app&.cross_platform?
        return ready.any? { |i| i.category.eql?(category.to_s) }
      end

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

    def slack_notifications?
      kept.notification.first&.slack_integration?
    end

    def vcs_provider
      kept.version_control.first&.providable
    end

    def ci_cd_provider
      kept.ci_cd.connected.first&.providable
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

    def existing_integration(app, providable_type)
      app.integrations.connected.find_by(providable_type: providable_type)
    end

    private

    def providable_error_message(meta)
      meta[:value].errors.full_messages[0]
    end
  end

  def disconnectable?
    return false if app.active_runs.exists?
    Step.kept.where(integration: self).none?
  end

  def disconnect
    return unless disconnectable?
    update(status: :disconnected, discarded_at: Time.current)
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
    unless providable&.valid?
      errors.add(:base, providable.errors.full_messages[0])
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
