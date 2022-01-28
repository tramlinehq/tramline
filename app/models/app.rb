class App < ApplicationRecord
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization"
  has_many :integrations
  has_many :trains, class_name: "Releases::Train", foreign_key: :app_id

  friendly_id :name, use: :slugged
end
