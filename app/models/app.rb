class App < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization", optional: false
  has_many :integrations, inverse_of: :app
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id
  has_many :sign_off_groups
  has_one :config, class_name: "AppConfig"

  validates :bundle_identifier, uniqueness: {scope: :organization_id}

  enum platform: {android: "android", ios: "ios"}

  accepts_nested_attributes_for :sign_off_groups, allow_destroy: true, reject_if: proc { |attributes| attributes["name"].blank? }

  after_initialize :initialize_config, if: :new_record?
  after_initialize :set_default_platform, if: :new_record?

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

  def initialize_config
    build_config
  end

  def bump_build_number!
    self.build_number = build_number + 1
    save!
    build_number.to_s
  end
end
