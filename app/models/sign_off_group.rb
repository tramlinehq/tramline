class SignOffGroup < ApplicationRecord
  belongs_to :app
  has_many :sign_off_group_memberships, dependent: :destroy
  has_many :sign_off_members, through: :sign_off_group_memberships, source: :user
end
