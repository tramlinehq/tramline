class Releases::Step::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :was_run_at

  has_one :build_artifact, foreign_key: :train_step_runs_id
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id
  belongs_to :train_run, class_name: "Releases::Train::Run", foreign_key: :train_run_id

  enum status: {on_track: "on_track", halted: "halted", finished: "finished"}

  attr_accessor :current_user

  delegate :transaction, to: ActiveRecord::Base
  delegate :release_branch, to: :train_run

  def automatons!
    Automatons::Workflow.dispatch!(step: step, ref: release_branch, release: train_run)
  end

  def wrap_up_run!
    self.status = Releases::Step::Run.statuses[:finished]

    train_run.perform_post_release! if step.last?

    save!
  end
end
