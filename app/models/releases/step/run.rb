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

  after_create :reset_approval!

  enum status: {on_track: "on_track", halted: "halted", success: "success", failed: "failed"}
  enum approval_status: {pending: "pending", approved: "approved", rejected: "rejected"}, _prefix: "approval"

  attr_accessor :current_user

  delegate :release_branch, to: :train_run

  def automatons!
    Automatons::Workflow.dispatch!(step: step, ref: release_branch, step_run: self)
  end

  def mark_success!
    self.status = Releases::Step::Run.statuses[:success]
    save!
  end

  def mark_failed!
    self.status = Releases::Step::Run.statuses[:failed]
    save!
  end

  def mark_halted!
    self.status = Releases::Step::Run.statuses[:halted]
    save!
  end

  def reset_approval!
    if !sign_required?
      approval_approved!
    elsif is_approved?
      approval_approved!
    elsif is_rejected?
      approval_rejected!
    else
      approval_pending!
    end
  end

  def is_approved?
    train.sign_off_groups.all? do |group|
      step.sign_offs.exists?(sign_off_group: group, signed: true, commit: commit)
    end
  end

  def is_rejected?
    # FIXME: Should rejection needs to be from all groups, or just one group?
    train.sign_off_groups.any? do |group|
      step.sign_offs.exists?(sign_off_group: group, signed: false, commit: commit)
    end
  end

  def finished?
    success? || failed?
  end
end
