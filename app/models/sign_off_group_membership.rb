# == Schema Information
#
# Table name: sign_off_group_memberships
#
#  id                :uuid             not null, primary key
#  sign_off_group_id :uuid             not null
#  user_id           :uuid             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class SignOffGroupMembership < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :user, class_name: "Accounts::User"
end
