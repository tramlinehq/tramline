class Accounts::Membership < ApplicationRecord
  include Roleable
  has_paper_trail

  belongs_to :user, inverse_of: :memberships, required: true
  belongs_to :organization, inverse_of: :memberships, required: true

  validates :user_id, uniqueness: { scope: :organization_id }
end
