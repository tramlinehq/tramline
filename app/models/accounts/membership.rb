class Accounts::Membership < ApplicationRecord
  belongs_to :user, inverse_of: :memberships
  belongs_to :organization, inverse_of: :memberships

  enum role: {owner: "owner", manager: "manager", developer: "developer"}
end
