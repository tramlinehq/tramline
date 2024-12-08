# == Schema Information
#
# Table name: approval_items
#
#  id                   :bigint           not null, primary key
#  content              :string           not null
#  status               :string           default("not_started")
#  status_changed_at    :datetime         indexed
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  author_id            :uuid             not null, indexed
#  release_id           :uuid             not null, indexed
#  status_changed_by_id :uuid             indexed
#
class ApprovalItem < ApplicationRecord
  MAX_CONTENT_LENGTH = 80

  belongs_to :release
  belongs_to :author, class_name: "Accounts::User"
  belongs_to :status_changed_by, class_name: "Accounts::User", optional: true
  has_many :approval_assignees, dependent: :destroy

  delegate :organization, :train, :release_pilot, to: :release

  validate :train_approvals_enabled, on: :create
  validate :writers_as_authors_only, on: :create
  validates :content, presence: true, length: {maximum: ApprovalItem::MAX_CONTENT_LENGTH}, on: :create

  before_destroy :ensure_not_started, prepend: true do
    throw(:abort) if errors.present?
  end

  enum :status, {
    not_started: "not_started",
    in_progress: "in_progress",
    blocked: "blocked",
    approved: "approved"
  }, validate: true

  def update_status(status, assignee)
    return true if approved?
    return unless release.active?

    with_lock do
      return true if approved?

      if edit_allowed?(assignee)
        self.status_changed_by = assignee
        self.status_changed_at = Time.current
        self.status = status
        save
      else
        errors.add(:assignee, "is not authorized to update this item")
        false
      end
    end
  end

  def edit_allowed?(potential_assignee)
    self_assigned?(potential_assignee) || approval_assignees.exists?(assignee: potential_assignee)
  end

  private

  def train_approvals_enabled
    unless train.approvals_enabled?
      errors.add(:base, "Cannot create approvals when approvals are disabled on the train-level")
    end
  end

  def self_assigned?(assignee)
    approval_assignees.none? && author == assignee
  end

  def writers_as_authors_only
    unless author.writer_for?(organization)
      errors.add(:author, "must be a developer")
    end
  end

  def release_pilots_as_authors_only
    if author != release_pilot
      errors.add(:author, "must be a release captain")
    end
  end

  def ensure_not_started
    unless not_started?
      errors.add(:base, "Cannot delete an approval item that has already started.")
    end
  end
end
