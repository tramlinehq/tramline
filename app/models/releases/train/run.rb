class Releases::Train::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  belongs_to :train, class_name: "Releases::Train"
  has_many :step_runs, class_name: "Releases::Step::Run", foreign_key: :train_run_id

  enum status: { on_track: "on_track", error: "error", finished: "finished" }

  def last_running_step
    step_runs.on_track.last
  end

  def last_run_step
    step_runs.finished.last
  end

  def release_branch
    was_run_at.strftime("rel/#{train.display_name}/#{code_name}/%d-%m-%Y")
  end
end
