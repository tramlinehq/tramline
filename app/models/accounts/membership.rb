class Accounts::Membership < ApplicationRecord
  has_paper_trail

  belongs_to :user, inverse_of: :memberships, required: true
  belongs_to :organization, inverse_of: :memberships, required: true

  enum role: { owner: "owner", manager: "manager", developer: "developer" }

  validates :user_id, uniqueness: { scope: :organization_id }
end
