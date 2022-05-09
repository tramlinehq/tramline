class Integration < ApplicationRecord
  has_paper_trail
  using RefinedString

  belongs_to :app
  belongs_to :providable, polymorphic: true

  class IntegrationNotImplemented < StandardError; end

  unless const_defined?(:LIST)
    LIST = {
      "version_control" => %w[GithubIntegration],
      "ci_cd" => %w[GithubIntegration],
      "notification" => %w[SlackIntegration],
      "build_channel" => %w[SlackIntegration]
    }.freeze
  end

  CATEGORY_DESCRIPTIONS = {
    "version_control": "Automatically create release branches, tags, and more.",
    "ci_cd": "Keep up to date with the status of the latest release builds as they're made available.",
    "notification": "Send release activity notifications at the right time, to the right people.",
    "build_channel": "See where your release stands."
  }.freeze

  enum category: LIST.keys.zip(LIST.keys).to_h

  enum status: {
    connected: "connected",
    disconnected: "disconnected"
  }

  validate -> { providable_type.in?(LIST[category]) }

  attr_accessor :current_user, :code

  scope :vcs_provider, -> { version_control.first.providable }
  scope :ci_cd_provider, -> { ci_cd.first.providable }
  scope :notification_provider, -> { notification.first.providable }

  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected]
  MINIMAL_REQUIRED_SET = [:version_control, :ci_cd, :notification]

  def self.ready?
    where(category: MINIMAL_REQUIRED_SET, status: :connected).size == MINIMAL_REQUIRED_SET.size
  end

  def connect?
    !connected?
  end

  def channels
    providable.channels
  end

  def install_path
    providable.install_path
  end

  def complete_access
    providable.complete_access
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
end
