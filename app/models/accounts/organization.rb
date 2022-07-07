class Accounts::Organization < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  has_many :memberships, dependent: :delete_all, inverse_of: :organization
  has_many :users, through: :memberships, dependent: :delete_all
  has_many :apps, dependent: :destroy
  has_many :invites, dependent: :destroy

  enum status: {active: "active", dormant: "dormant", guest: "guest"}

  friendly_id :name, use: :slugged

  auto_strip_attributes :name, squish: true
end
