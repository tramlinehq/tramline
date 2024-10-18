# == Schema Information
#
# Table name: approval_assignees
#
#  id               :bigint           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  approval_item_id :bigint           not null, indexed
#  assignee_id      :uuid             not null, indexed
#
class ApprovalAssignee < ApplicationRecord
  belongs_to :approval_item
  belongs_to :assignee, class_name: "Accounts::User"
end
