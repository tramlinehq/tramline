class SignOffGroup < ApplicationRecord
  belongs_to :app
  has_many :memberships, dependent: :destroy, class_name: 'SignOffGroupMembership'
  has_many :members, through: :memberships, source: :user
  has_many :sign_offs, dependent: :destroy
end
