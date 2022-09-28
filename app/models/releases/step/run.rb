class Releases::Step::Run < ApplicationRecord
  has_paper_trail
  include AASM

  class WorkflowTriggerFailed < StandardError; end

  self.ignored_columns = [:previous_step_run_id]

  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :runs
  belongs_to :train_run, class_name: "Releases::Train::Run"
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: :releases_commit_id, inverse_of: :step_runs
  has_one :build_artifact, foreign_key: :train_step_runs_id, inverse_of: :step_run, dependent: :destroy
  has_many :deployment_runs, foreign_key: :train_step_run_id, inverse_of: :step_run

  validates :build_version, uniqueness: { scope: [:train_step_id, :train_run_id] }
  validates :train_step_id, uniqueness: { scope: :releases_commit_id }
  validates :initial_rollout_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }

  after_create :reset_approval!
  after_create :trigger_workflow_run!

  scope :active, -> { where.not(status: [:ci_workflow_unavailable, :ci_workflow_failed, :ci_workflow_halted, :deployment_failed, :success]) }

  STATES = {
    on_track: "on_track",
    ci_workflow_triggered: "ci_workflow_triggered",
    ci_workflow_unavailable: "ci_workflow_unavailable",
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

    event :ci_trigger, after_commit: -> { Releases::Step::FindWorkflowRun.perform_async(id) } do
      transitions from: :on_track, to: :ci_workflow_triggered
    end

    event :ci_started, after_commit: -> { WorkflowProcessors::WorkflowRun.perform_later(id) } do
      transitions from: [:on_track, :ci_workflow_triggered], to: :ci_workflow_started
    end

    event :ci_unavailable do
      transitions from: [:on_track, :ci_workflow_triggered], to: :ci_workflow_unavailable
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
      before { Releases::Step::Promote.perform_later(id, initial_rollout_percentage) }
      transitions from: :pending_deployment, to: :deployment_started, guard: :promotable?
    end

    event :fail_deploy do
      transitions from: [:pending_deployment, :deployment_started], to: :deployment_failed
    end

    event :finish do
      # FIXME: remove this
      after { build_artifact&.release_situation&.update!(status: ReleaseSituation.statuses[:released]) }
      # FIXME: potential race condition here if a commit lands right here... . at this point...
      # ...and starts another run, but the release phase is triggered for an effectively stale run
      after { release.update!(status: Releases::Train::Run.statuses[:release_phase]) if step.last? }
      transitions from: [:pending_deployment, :deployment_started], to: :success
    end
  end

  enum approval_status: { pending: "pending", approved: "approved", rejected: "rejected" }, _prefix: "approval"

  attr_accessor :current_user

  delegate :train, to: :train_run
  delegate :release_branch, to: :train_run
  delegate :commit_hash, to: :commit
  alias_method :release, :train_run

  def start_ci!(ci_ref, ci_link)
    transaction do
      update(ci_ref: ci_ref, ci_link: ci_link)
      ci_started!
    end
  end

  def trigger_workflow_run!
    version_code = train.app.bump_build_number!
    inputs = {
      versionCode: version_code,
      versionName: build_version
    }

    raise WorkflowTriggerFailed unless train.ci_cd_provider.trigger_workflow_run!(workflow_name, release_branch, inputs)
    update!(build_number: version_code)
    ci_trigger!
  end

  def find_workflow_run
    train.ci_cd_provider.find_workflow_run(workflow_name, release_branch, commit_hash)
  end

  def get_workflow_run
    train.ci_cd_provider.get_workflow_run(ci_ref)
  end

  def uploading?
    pending_deployment? && build_artifact&.release_situation.blank?
  end

  def last_deployment_run
    deployment_runs.joins(:deployment).order(:deployment_number).last
  end

  def last_run_for(deployment)
    deployment_runs.where(deployment: deployment).last
  end

  def next_deployment
    return step.deployments.first if deployment_runs.empty?
    last_deployment_run.deployment.next
  end

  def reset_approval!
    return approval_approved! unless sign_required?
    return approval_approved! if is_approved?
    return approval_rejected! if is_rejected?
    approval_pending!
  end

  # approval needs to be from all groups
  def is_approved?
    train.sign_off_groups.all? do |group|
      step.sign_offs.exists?(sign_off_group: group, signed: true, commit: commit)
    end
  end

  # rejection needs to be from any one group
  def is_rejected?
    train.sign_off_groups.any? do |group|
      step.sign_offs.exists?(sign_off_group: group, signed: false, commit: commit)
    end
  end

  def workflow_name
    step.ci_cd_channel.keys.first
  end
end
