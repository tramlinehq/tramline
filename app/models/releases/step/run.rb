class Releases::Step::Run < ApplicationRecord
  self.implicit_order_column = :was_run_at

  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id
  belongs_to :train_run, class_name: "Releases::Train::Run", foreign_key: :train_run_id

  enum status: { on_track: "on_track", halted: "halted", finished: "finished" }
end
