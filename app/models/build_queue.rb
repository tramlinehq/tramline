# == Schema Information
#
# Table name: build_queues
#
#  id           :uuid             not null, primary key
#  applied_at   :datetime
#  is_active    :boolean          default(TRUE), indexed
#  scheduled_at :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  release_id   :uuid             not null, indexed
#
class BuildQueue < ApplicationRecord
  belongs_to :release, inverse_of: :build_queues
  has_many :commits, dependent: :destroy, inverse_of: :build_queue

  scope :active, -> { where(is_active: true) }
  delegate :train, to: :release
  delegate :build_queue_size, to: :train

  after_create_commit :schedule_kickoff!

  def add_commit!(commit, can_apply: true)
    commits << commit
    if commits.size >= build_queue_size && can_apply
      Signal.build_queue_can_be_applied!(self)
    end
  end

  def schedule_kickoff!
    BuildQueueApplicationJob.set(wait_until: scheduled_at).perform_async(id)
  end

  def head_commit = commits.last

  def can_be_applied?
    return false if commits.empty?
    return true unless version_bump_required?
    
    # Check if all platform runs have their version bump PRs merged
    release.release_platform_runs.all? do |run|
      !run.version_bump_required? || !run.has_pending_version_bump_pr?
    end
  end

  def version_bump_required?
    release.release_platform_runs.any?(&:version_bump_required?)
  end

  def apply_if_ready!
    Signal.build_queue_can_be_applied!(self) if can_be_applied?
  end
end
