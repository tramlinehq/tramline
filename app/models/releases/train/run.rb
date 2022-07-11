class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  belongs_to :train, class_name: "Releases::Train"
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id, dependent: :destroy, inverse_of: :train_run
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id", dependent: :destroy, inverse_of: :train_run

  enum status: {on_track: "on_track", error: "error", finished: "finished"}

  before_create :set_version

  def last_running_step
    step_runs.on_track.last
  end

  def last_run_step
    step_runs.finished.last
  end

  def next_step
    return train.steps.first if step_runs.empty?

    step_runs.joins(:step).order("step_number").last.step.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def release_branch
    branch_name
  end

  def set_version
    self.release_version = train.bump_version!.to_s
  end

  def perform_post_release!
    Services::PostRelease.call(self)
  end

  def branch_url
    train.app.vcs_provider&.branch_url(train.app.config&.code_repository_name, branch_name)
  end

  def last_commit
    commits.last
  end
end
