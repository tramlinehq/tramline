class Integration < ApplicationRecord
  has_paper_trail
  using RefinedString

  belongs_to :app
  delegated_type :providable, types: %w[GithubIntegration GitlabIntegration SlackIntegration GooglePlayStoreIntegration]

  class IntegrationNotImplemented < StandardError; end

  LIST = {
    "version_control" => %w[GithubIntegration GitlabIntegration],
    "ci_cd" => %w[GithubIntegration],
    "notification" => %w[SlackIntegration],
    "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration]
  }.freeze

  CATEGORY_DESCRIPTIONS = {
    version_control: "Automatically create release branches and tags, and merge release PRs.",
    ci_cd: "Trigger workflows to create builds and stay up-to-date as they're made available.",
    notification: "Send release activity notifications at the right time, to the right people.",
    build_channel: "Send builds to the right deployment service for the right stakeholders."
  }.freeze

  MULTI_INTEGRATION_CATEGORIES = ["build_channel"]

  enum category: LIST.keys.zip(LIST.keys).to_h

  enum status: {
    connected: "connected",
    disconnected: "disconnected"
  }

  validates :category, presence: true
  validate :provider_in_category

  attr_accessor :current_user, :code

  delegate :install_path, to: :providable

  before_create :set_connected

  MINIMAL_REQUIRED_SET = [:version_control, :ci_cd, :notification]
  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected]
  DEFAULT_INITIAL_STATUS = Integration.statuses[:disconnected]

  def self.ready?
    where(category: MINIMAL_REQUIRED_SET, status: :connected).size == MINIMAL_REQUIRED_SET.size
  end

  def self.vcs_provider
    version_control.first&.providable
  end

  def self.ci_cd_provider
    ci_cd.first&.providable
  end

  def self.notification_provider
    notification.first&.providable
  end

  def self.slack_build_channel_provider
    build_channel.where(providable_type: "SlackIntegration").first.providable
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
end
