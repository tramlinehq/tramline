# == Schema Information
#
# Table name: sign_off_groups
#
#  id         :uuid             not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :uuid             not null, indexed
#
class SignOffGroup < ApplicationRecord
  belongs_to :app
  has_many :memberships, dependent: :destroy, class_name: "SignOffGroupMembership"
  has_many :members, through: :memberships, source: :user
  has_many :sign_offs, dependent: :destroy
  has_many :trains, through: :train_sign_off_groups

  auto_strip_attributes :name, squish: true
end
