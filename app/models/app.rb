class App < ApplicationRecord
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization"
  has_many :integrations, inverse_of: :app
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id

  enum role: { android: "android", ios: "ios" }

  after_initialize :set_default_platform

  friendly_id :name, use: :slugged

  delegate :ready?, to: :integrations, prefix: :integrations_are

  def set_default_platform
    self.platform = App.roles[:android]
  end

  def bump_build_number!
    self.build_number = build_number + 1
    save!
  end
end
