class ForwardMergeQueue < ApplicationRecord
  belongs_to :release, inverse_of: :forward_merge_queue
  has_one :commit, dependent: :nullify, inverse_of: :forward_merge_queue
  has_one :pull_request, dependent: :nullify, inverse_of: :forward_merge_queue

  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    success: "success",
    failed: "failed",
    manually_picked: "manually_picked"
  }

  scope :sequential, -> { includes(:commit).order("commits.timestamp DESC") }
  scope :actionable, -> { where(status: [:pending, :failed]) }

  delegate :train, to: :release
  delegate :short_sha, :commit_hash, :message, :author_name, :author_login,
    :author_email, :url, :timestamp, to: :commit

  def actionable? = pending? || failed?
end
