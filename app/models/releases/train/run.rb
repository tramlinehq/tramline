class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  belongs_to :train, class_name: "Releases::Train"
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id
  has_many :commits, class_name: "Releases::Commit", foreign_key: "train_run_id"

  enum status: {on_track: "on_track", error: "error", finished: "finished"}

  before_create :set_version

  def last_running_step
    step_runs.on_track.last
  end

  def last_run_step
    step_runs.finished.last
  end

  def next_step
    step_runs.joins(:step).order("step_number").last.step.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def release_branch
    was_run_at.strftime("r/#{train.display_name}/%Y-%m-%d")
  end

  def set_version
    self.release_version = train.bump_version!.to_s
  end
end
