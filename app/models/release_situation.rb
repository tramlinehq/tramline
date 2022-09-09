class ReleaseSituation < ApplicationRecord
  has_paper_trail

  belongs_to :build_artifact, inverse_of: :release_situation

  enum status: {
    bundle_uploaded: "bundle_uploaded",
    staged_rollout: "staged_rollout",
    released: "released",
    rejected: "rejected",
    failed: "failed"
  }

  validates :status, presence: true
end
