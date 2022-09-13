class Releases::Step::Run < ApplicationRecord
  has_paper_trail
  include AASM

  self.implicit_order_column = :created_at
  self.ignored_columns = [:previous_step_run_id]

  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :runs
  belongs_to :train_run, class_name: "Releases::Train::Run"
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: "releases_commit_id", inverse_of: :step_runs
  has_one :train, through: :train_run
  has_one :build_artifact, foreign_key: :train_step_runs_id, inverse_of: :step_run, dependent: :destroy

  validates :build_version, uniqueness: {scope: [:train_step_id, :train_run_id]}
  validates :build_number, uniqueness: {scope: [:train_run_id]}
  validates :train_step_id, uniqueness: {scope: :releases_commit_id}

  after_create :reset_approval!

  STATES = {
    on_track: "on_track",
    ci_workflow_started: "ci_workflow_started",
    ci_workflow_failed: "ci_workflow_failed",
    ci_workflow_halted: "ci_workflow_halted",
    pending_deployment: "pending_deployment",
    deployment_started: "deployment_started",
    deployment_failed: "deployment_failed",
    success: "success"
  }

  enum status: STATES

  aasm column: :status, requires_lock: true, requires_new_transaction: false, enum: true, create_scopes: false do
    state :on_track, initial: true
    state(*STATES.keys)

    event :ci_start do
      transitions from: :on_track, to: :ci_workflow_started
    end

    event :ci_failed do
      transitions from: :ci_workflow_started, to: :ci_workflow_failed
    end

    event :ci_cancelled do
      transitions from: :ci_workflow_started, to: :ci_workflow_halted
    end

    event :about_to_deploy do
      transitions from: :ci_workflow_started, to: :pending_deployment
    end

    event :promote do
      before { Releases::Step::PromoteOnPlaystore.perform_later(id) }
      transitions from: :pending_deployment, to: :deployment_started, guard: :promotable?
    end

    event :fail_deploy do
      transitions from: :deployment_started, to: :deployment_failed
    end

    event :finish do
      after { build_artifact&.release_situation&.update!(status: ReleaseSituation.statuses[:released]) }
      transitions from: [:pending_deployment, :deployment_started], to: :success
    end
  end

  enum approval_status: {pending: "pending", approved: "approved", rejected: "rejected"}, _prefix: "approval"

  attr_accessor :current_user

  delegate :release_branch, to: :train_run

  def automatons!
    Automatons::Workflow.dispatch!(step: step, ref: release_branch, step_run: self)
  end

  def uploading?
    pending_deployment? && build_artifact&.release_situation.blank?
  end

  def promotable?
    build_artifact&.release_situation&.bundle_uploaded? &&
      step.build_artifact_integration.eql?("GooglePlayStoreIntegration")
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
end
