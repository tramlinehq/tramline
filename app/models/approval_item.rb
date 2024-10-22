# == Schema Information
#
# Table name: approval_items
#
#  id             :bigint           not null, primary key
#  approved_at    :datetime         indexed
#  content        :string           not null
#  status         :string           default("not_started")
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  approved_by_id :uuid             indexed
#  author_id      :uuid             not null, indexed
#  release_id     :uuid             not null, indexed
#
class ApprovalItem < ApplicationRecord
  MAX_CONTENT_LENGTH = 200

  belongs_to :release
  belongs_to :author, class_name: "Accounts::User"
  belongs_to :approved_by, class_name: "Accounts::User", optional: true
  has_many :approval_assignees, dependent: :destroy

  delegate :organization, :release_pilot, to: :release

  validate :release_pilots_as_authors_only, on: :create
  validates :content, presence: true, length: {maximum: ApprovalItem::MAX_CONTENT_LENGTH}

  scope :approved, -> { where(status: ApprovalItem.statuses[:approved]).where.not(approved_at: nil).where.not(approved_by: nil) }

  enum :status, {
    not_started: "not_started",
    in_progress: "in_progress",
    blocked: "blocked",
    approved: "approved",
    rejected: "rejected"
  }

  def update_status(status, assignee)
    return true if approved?
    if self_assigned?(assignee) || approval_assignees.exists?(assignee: assignee)
      if status == ApprovalItem.statuses[:approved]
        self.approved_by = assignee
        self.approved_at = Time.current
      end
      self.status = status
      save
    else
      errors.add(:assignee, "is not authorized to update this item")
      false
    end
  end

  def approved?
    status == ApprovalItem.statuses[:approved] && approved_at.present? && approved_by.present?
  end

  private

  def self_assigned?(assignee)
    approval_assignees.none? && author == assignee
  end

  def release_pilots_as_authors_only
    if author != release_pilot
      errors.add(:author, "must be a release pilot")
    end
  end
end

# release will have many approval items
# can be assigned to anyone
# can only be approved by the assigned users
