class App < ApplicationRecord
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization"
  has_many :integrations
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id

  enum role: {android: "android", ios: "ios"}

  after_initialize :set_platform

  friendly_id :name, use: :slugged

  def set_platform
    self.platform = App.roles[:android]
  end
end
