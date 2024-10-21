# == Schema Information
#
# Table name: approval_items
#
#  id             :bigint           not null, primary key
#  approved_at    :datetime         indexed
#  content        :string           not null
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

  scope :approved, -> { where.not(approved_at: nil).where.not(approved_by: nil) }

  def approve(assignee)
    return true if approved?

    if self_assigned?(assignee) || approval_assignees.exists?(assignee: assignee)
      self.approved_by = assignee
      self.approved_at = Time.current
      save
    else
      errors.add(:assignee, "is not authorized to approve this item")
      false
    end
  end

  def approved?
    approved_at.present? && approved_by.present?
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
