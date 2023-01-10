# == Schema Information
#
# Table name: integrations
#
#  id              :uuid             not null, primary key
#  category        :string           not null
#  providable_type :string           indexed => [providable_id]
#  status          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  app_id          :uuid             not null, indexed
#  providable_id   :uuid             indexed => [providable_type]
#
class Integration < ApplicationRecord
  has_paper_trail
  using RefinedString

  belongs_to :app
  delegated_type :providable, types: %w[GithubIntegration GitlabIntegration SlackIntegration GooglePlayStoreIntegration BitriseIntegration]

  class IntegrationNotImplemented < StandardError; end

  class UnsupportedAction < StandardError; end

  class NoBuildArtifactAvailable < StandardError; end

  LIST = {
    "version_control" => %w[GithubIntegration GitlabIntegration],
    "ci_cd" => %w[GithubIntegration BitriseIntegration],
    "notification" => %w[SlackIntegration],
    "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration]
  }.freeze

  enum category: LIST.keys.zip(LIST.keys).to_h

  enum status: {
    connected: "connected",
    disconnected: "disconnected"
  }

  CATEGORY_DESCRIPTIONS = {
    version_control: "Automatically create release branches and tags, and merge release PRs.",
    ci_cd: "Trigger workflows to create builds and stay up-to-date as they're made available.",
    notification: "Send release activity notifications at the right time, to the right people.",
    build_channel: "Send builds to the right deployment service for the right stakeholders."
  }.freeze

  MULTI_INTEGRATION_CATEGORIES = ["build_channel"].freeze

  MINIMUM_REQUIRED_SET = [:version_control, :ci_cd, :build_channel].freeze
  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected].freeze
  DEFAULT_INITIAL_STATUS = Integration.statuses[:disconnected].freeze

  validates :category, presence: true
  validate :provider_in_category

  validates_associated :providable, message: proc { |_p, meta| providable_error_message(meta) }

  attr_accessor :current_user, :code

  delegate :install_path, to: :providable

  scope :ready, -> { where(category: MINIMUM_REQUIRED_SET, status: :connected) }

  before_create :set_connected

  class << self
    def by_categories_for(app)
      existing_integrations = app.integrations.includes(:providable)

      LIST.each_with_object({}) do |(category, providers), combination|
        existing_integration = existing_integrations.select { |integration| integration.category.eql?(category) }
        combination[category] ||= []

        existing_integration.each do |integration|
          combination[category] << integration
        end

        next if MULTI_INTEGRATION_CATEGORIES.exclude?(category) && combination[category].present?

        (providers - existing_integration.pluck(:providable_type)).each do |provider|
          next if provider.eql?("GitlabIntegration") && !Flipper.enabled?(:gitlab_integration)
          next if provider.eql?("BitriseIntegration") && !Flipper.enabled?(:bitrise_integration)

          integration =
            app
              .integrations
              .new(category: categories[category], providable: provider.constantize.new, status: DEFAULT_INITIAL_STATUS)

          combination[category] << integration
        end

        combination
      end
    end

    def ready?
      ready.pluck(:category).uniq.size == MINIMUM_REQUIRED_SET.size
    end

    def vcs_provider
      version_control.first&.providable
    end

    def ci_cd_provider
      ci_cd.first&.providable
    end

    def notification_provider
      notification.first&.providable
    end

    def slack_build_channel_provider
      build_channel.where(providable_type: "SlackIntegration").first.providable
    end

    private

    def providable_error_message(meta)
      meta[:value].errors.full_messages[0]
    end
  end

  def installation_state
    {
      organization_id: app.organization.id,
      app_id: app.id,
      integration_category: category,
      integration_provider: providable_type,
      user_id: current_user.id
    }.to_json.encode
  end

  def set_connected
    self.status = DEFAULT_CONNECT_STATUS
  end

  def provider_in_category
    unless providable_type&.in?(LIST[category])
      errors.add(:providable_type, "Provider is not a part of this type of Integration")
    end
  end

  def store?
    build_channel? && providable.store?
  end
end
