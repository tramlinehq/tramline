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

  delegate :organization, to: :approval_item
  delegate :preferred_name, :full_name, :email, to: :assignee

  validate :assignee_belongs_to_org

  after_commit :notify_assignee, on: :create

  private

  def assignee_belongs_to_org
    unless assignee.organizations&.exists?(id: organization.id)
      errors.add(:assignee, "does not belong to the organization")
    end
  end

  def notify_assignee
    if assignee.email.present?
      ApprovalAssignmentMailer.notify(self).deliver_later
    end
  end
end
