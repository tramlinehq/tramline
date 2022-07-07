class SignOffGroupMembership < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :user, class_name: "Accounts::User"
end
