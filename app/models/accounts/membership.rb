class Accounts::Membership < ApplicationRecord
  enum role: {owner: "owner", manager: "manager", developer: "developer"}

  belongs_to :user, inverse_of: :memberships
  belongs_to :organization, inverse_of: :memberships
end
