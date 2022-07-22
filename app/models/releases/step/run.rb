class Releases::Step::Run < ApplicationRecord
  has_paper_trail
  self.implicit_order_column = :created_at

  self.ignored_columns = [:previous_step_run_id]

  has_one :build_artifact, foreign_key: :train_step_runs_id, inverse_of: :step_run, dependent: :destroy
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :runs
  belongs_to :train_run, class_name: "Releases::Train::Run"
  has_one :train, through: :train_run
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: "releases_commit_id", inverse_of: :step_runs

  validates :train_step_id, uniqueness: {scope: :releases_commit_id}
  validates :build_version, uniqueness: {scope: [:train_step_id, :train_run_id]}
  validates :build_number, uniqueness: {scope: [:train_run_id]}

  enum status: {on_track: "on_track", halted: "halted", finished: "finished"}

  attr_accessor :current_user

  delegate :transaction, to: ActiveRecord::Base
  delegate :release_branch, to: :train_run

  def automatons!
    Automatons::Workflow.dispatch!(step: step, ref: release_branch, step_run: self)
  end

  def wrap_up_run!
    self.status = Releases::Step::Run.statuses[:finished]
    save!

    train_run.perform_post_release! if step.last?
  end

  def signed?
    return true unless sign_required?

    train.sign_off_groups.all? do |group|
      step.sign_offs.exists?(sign_off_group: group, signed: true, commit: commit)
    end
  end
end
