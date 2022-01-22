class Accounts::Membership < ApplicationRecord
  enum role: {executive: "executive", developer: "developer"}

  belongs_to :user, inverse_of: :memberships
  belongs_to :organization, inverse_of: :memberships
end
