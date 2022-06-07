class App < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization", required: true
  has_many :integrations, inverse_of: :app
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id
  has_one :config, class_name: "AppConfig"

  enum platform: {android: "android", ios: "ios"}

  after_initialize :set_default_platform

  friendly_id :name, use: :slugged

  delegate :vcs_provider, to: :integrations
  delegate :ci_cd_provider, to: :integrations
  delegate :notification_provider, to: :integrations

  def ready?
    integrations.ready? and config&.ready?
  end

  def set_default_platform
    self.platform = App.platforms[:android]
  end

  def bump_build_number!
    self.build_number = build_number + 1
    save!
    build_number.to_s
  end
end
