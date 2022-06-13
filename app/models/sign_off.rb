class SignOff < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :step
  belongs_to :user
end
