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

  def apply!
    head_commit&.trigger_step_runs
    update!(applied_at: Time.current, is_active: false)
    release.create_build_queue!
  end

  def add_commit!(commit, can_apply: true)
    commits << commit
    apply! if commits.size >= build_queue_size && can_apply
  end

  def add_commit_v2!(commit, can_apply: true)
    commits << commit

    if commits.size >= build_queue_size && can_apply
      Signal.build_queue_can_be_applied!(self)
    end
  end

  def schedule_kickoff!
    BuildQueueApplicationJob.set(wait_until: scheduled_at).perform_later(id)
  end

  def head_commit = commits.last
end
