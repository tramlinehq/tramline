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
      "build_channel" => %w[GooglePlayStoreIntegration SlackIntegration]
    }.freeze
  end

  CATEGORY_DESCRIPTIONS = {
    version_control: "Automatically create release branches, tags, and more.",
    ci_cd: "Keep up to date with the status of the latest release builds as they're made available.",
    notification: "Send release activity notifications at the right time, to the right people.",
    build_channel: "See where your release stands."
  }.freeze

  enum category: LIST.keys.zip(LIST.keys).to_h

  enum status: {
    connected: "connected",
    disconnected: "disconnected"
  }

  validates :category, presence: true
  validate :provider_in_category

  attr_accessor :current_user, :code

  scope :vcs_provider, -> { version_control.first.providable }
  scope :ci_cd_provider, -> { ci_cd.first.providable }
  scope :notification_provider, -> { notification.first.providable }

  delegate :install_path, to: :providable

  before_create :set_connected

  DEFAULT_CONNECT_STATUS = Integration.statuses[:connected]
  DEFAULT_INITIAL_STATUS = Integration.statuses[:disconnected]
  MINIMAL_REQUIRED_SET = [:version_control, :ci_cd, :notification].freeze

  def self.ready?
    where(category: MINIMAL_REQUIRED_SET, status: :connected).size == MINIMAL_REQUIRED_SET.size
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
    errors.add(:providable_type, "Provider is not a part of this type of Integration") unless providable_type&.in?(LIST[category])
  end
end
