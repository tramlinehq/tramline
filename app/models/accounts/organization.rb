class Accounts::Organization < ApplicationRecord
  extend FriendlyId

  enum status: {active: "active", dormant: "dormant", guest: "guest"}

  has_many :memberships, dependent: :delete_all, inverse_of: :organization
  has_many :users, through: :memberships, dependent: :delete_all
  has_many :apps

  friendly_id :name, use: :slugged

  auto_strip_attributes :name, squish: true
end
