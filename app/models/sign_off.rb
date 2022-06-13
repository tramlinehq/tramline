class SignOff < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :step, class_name: 'Releases::Step'
  belongs_to :user, class_name: 'Accounts::User'
end
