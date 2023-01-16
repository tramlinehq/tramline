# == Schema Information
#
# Table name: train_step_runs
#
#  id                         :uuid             not null, primary key
#  approval_status            :string           default("pending"), not null
#  build_number               :string
#  build_version              :string           not null
#  ci_link                    :string
#  ci_ref                     :string
#  initial_rollout_percentage :decimal(8, 5)
#  scheduled_at               :datetime         not null
#  sign_required              :boolean          default(TRUE)
#  status                     :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  releases_commit_id         :uuid             not null, indexed
#  train_run_id               :uuid             not null, indexed
#  train_step_id              :uuid             not null, indexed
#
class Releases::Step::Run < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable

  self.implicit_order_column = :scheduled_at

  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :runs
  belongs_to :train_run, class_name: "Releases::Train::Run"
  belongs_to :commit, class_name: "Releases::Commit", foreign_key: :releases_commit_id, inverse_of: :step_runs
  has_one :build_artifact, foreign_key: :train_step_runs_id, inverse_of: :step_run, dependent: :destroy
  has_many :deployment_runs, -> { includes(:deployment).order("deployments.deployment_number ASC") }, foreign_key: :train_step_run_id, inverse_of: :step_run, dependent: :destroy
  has_many :deployments, through: :step
  has_many :passports, as: :stampable, dependent: :destroy

  validates :build_version, uniqueness: {scope: [:train_step_id, :train_run_id]}
  validates :train_step_id, uniqueness: {scope: :releases_commit_id}
  validates :initial_rollout_percentage, numericality: {greater_than: 0, less_than_or_equal_to: 100, allow_nil: true}

  after_create :reset_approval!
  after_commit -> { create_stamp!(data: {name: step.name}) }, on: :create
  after_commit -> {
    status_update_stamp!(data: {name: step.name, sha_link: commit.url, sha: commit.short_sha})
  }, if: -> { saved_change_to_attribute?(:status) }, on: :update

  STAMPABLE_REASONS = %w[created status_changed]

  STATES = {
    on_track: "on_track",
    ci_workflow_triggered: "ci_workflow_triggered",
    ci_workflow_unavailable: "ci_workflow_unavailable",
    ci_workflow_started: "ci_workflow_started",
    ci_workflow_failed: "ci_workflow_failed",
    ci_workflow_halted: "ci_workflow_halted",
    build_ready: "build_ready",
    deployment_started: "deployment_started",
    deployment_failed: "deployment_failed",
    success: "success"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :on_track, initial: true
    state(*STATES.keys)

    event :trigger_ci, after_commit: -> { Releases::FindWorkflowRun.perform_async(id) } do
      before :trigger_workflow_run
      transitions from: :on_track, to: :ci_workflow_triggered
    end

    event :ci_start, after_commit: -> { WorkflowProcessors::WorkflowRunJob.perform_later(id) } do
      before :find_and_update_workflow_run
      transitions from: [:ci_workflow_triggered], to: :ci_workflow_started
    end

    event(:ci_unavailable, after_commit: -> { notify_on_failure!("Could not find the CI workflow!") }) do
      transitions from: [:on_track, :ci_workflow_triggered], to: :ci_workflow_unavailable
    end

    event(:fail_ci, after_commit: -> { notify_on_failure!("CI workflow failed!") }) do
      transitions from: :ci_workflow_started, to: :ci_workflow_failed
    end

    event(:cancel_ci, after_commit: -> { notify_on_failure!("CI workflow was halted!") }) do
      transitions from: :ci_workflow_started, to: :ci_workflow_halted
    end

    event(:finish_ci) { transitions from: :ci_workflow_started, to: :build_ready }
    event(:ready_to_deploy) { transitions from: :build_ready, to: :deployment_started }

    event(:fail_deploy, after_commit: -> { notify_on_failure!("Deployment failed!") }) do
      transitions from: [:build_ready, :deployment_started], to: :deployment_failed
    end

    event(:finish) { transitions from: [:build_ready, :deployment_started], to: :success, guard: :finished_deployments? }
  end

  enum approval_status: {pending: "pending", approved: "approved", rejected: "rejected"}, _prefix: "approval"

  attr_accessor :current_user

  delegate :train, :release_branch, to: :train_run
  delegate :ci_cd_provider, :unzip_artifact?, to: :train
  delegate :commit_hash, to: :commit
  delegate :download_url, to: :build_artifact
  alias_method :release, :train_run

  def update_ci_metadata!(workflow_run)
    return if workflow_run.try(:[], :ci_ref).blank?
    update!(ci_ref: workflow_run[:ci_ref], ci_link: workflow_run[:ci_link])
  end

  def find_and_update_workflow_run
    return if workflow_found?

    find_workflow_run
      .then { |wr| update_ci_metadata!(wr) }
  end

  def trigger_workflow_run
    version_code = train.app.bump_build_number!
    inputs = {
      version_code: version_code,
      build_version: build_version
    }
    update!(build_number: version_code)

    ci_cd_provider
      .trigger_workflow_run!(workflow_name, release_branch, inputs, commit_hash)
      .then { |wr| update_ci_metadata!(wr) }
  end

  def workflow_found?
    ci_ref.present?
  end

  def find_workflow_run
    ci_cd_provider.find_workflow_run(workflow_name, release_branch, commit_hash)
  end

  def get_workflow_run
    ci_cd_provider.get_workflow_run(ci_ref)
  end

  def fetching_build?
    may_finish_ci? && build_artifact.blank?
  end

  def build_available?
    build_artifact.present?
  end

  def previous_run
    previous_runs.last
  end

  def other_runs
    train_run.step_runs_for(step).where.not(id:)
  end

  def previous_runs
    other_runs.where("scheduled_at < ?", scheduled_at)
  end

  def startable_deployment?(deployment)
    return false if train.inactive?
    return false if train.active_run.nil?
    return true if deployment.first? && deployment_runs.empty?
    next_deployment == deployment
  end

  def manually_startable_deployment?(deployment)
    return false if deployment.first?
    startable_deployment?(deployment) && last_deployment_run&.released?
  end

  def last_deployment_run
    deployment_runs.last
  end

  def last_run_for(deployment)
    deployment_runs.where(deployment: deployment).last
  end

  def next_deployment
    return step.deployments.first if deployment_runs.empty?
    last_deployment_run.deployment.next
  end

  def similar_deployment_runs_for(deployment_run)
    deployment_runs
      .where.not(id: deployment_run)
      .matching_runs_for(deployment_run.integration)
      .has_begun
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

  def in_progress?
    on_track? || ci_workflow_triggered? || ci_workflow_started? || build_ready? || deployment_started? || !is_approved?
  end

  def failed?
    ci_workflow_unavailable? || ci_workflow_failed? || ci_workflow_halted? || deployment_failed?
  end

  def done?
    is_approved? && success?
  end

  def status_summary
    {
      in_progress: in_progress?,
      done: done?,
      failed: failed?
    }
  end

  def workflow_name
    step.ci_cd_channel.keys.first
  end

  def notify_on_failure!(message)
    train.notify!(message, :step_failed, {reason: message, step_run: self})
  end

  def finished_deployments?
    deployment_runs.released.size == step.deployments.size
  end
end
