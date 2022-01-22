class App < ApplicationRecord
  extend FriendlyId

  belongs_to :organization, class_name: "Accounts::Organization"
  has_many :integrations

  friendly_id :name, use: :slugged
end
