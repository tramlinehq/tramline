class App < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization", required: true
  has_many :integrations, inverse_of: :app
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id

  enum platform: { android: "android", ios: "ios" }

  after_initialize :set_default_platform

  friendly_id :name, use: :slugged

  delegate :ready?, to: :integrations, prefix: :integrations_are
  delegate :completable?, to: :integrations, prefix: :integrations_are

  def set_default_platform
    self.platform = App.platforms[:android]
  end

  def bump_build_number!
    self.build_number = build_number + 1
    save!
    build_number.to_s
  end
end
