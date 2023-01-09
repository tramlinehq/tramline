# == Schema Information
#
# Table name: sign_off_group_memberships
#
#  id                :uuid             not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sign_off_group_id :uuid             not null, indexed
#  user_id           :uuid             not null, indexed
#
class SignOffGroupMembership < ApplicationRecord
  belongs_to :sign_off_group
  belongs_to :user, class_name: "Accounts::User"
end
