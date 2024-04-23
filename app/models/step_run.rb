# == Schema Information
#
# Table name: step_runs
#
#  id                      :uuid             not null, primary key
#  approval_status         :string           default("pending"), not null
#  build_notes_raw         :text             default([]), is an Array
#  build_number            :string           indexed => [build_version]
#  build_version           :string           not null, indexed => [build_number]
#  ci_link                 :string
#  ci_ref                  :string
#  scheduled_at            :datetime         not null
#  sign_required           :boolean          default(TRUE)
#  status                  :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             not null, indexed, indexed => [step_id]
#  release_platform_run_id :uuid             not null, indexed
#  slack_file_id           :string
#  step_id                 :uuid             not null, indexed, indexed => [commit_id]
#
class StepRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable

  self.ignored_columns += ["initial_rollout_percentage"]
  self.implicit_order_column = :scheduled_at

  BASE_WAIT_TIME = 10.seconds

  belongs_to :step, inverse_of: :step_runs
  belongs_to :release_platform_run
  belongs_to :commit, inverse_of: :step_runs
  has_one :build_artifact, inverse_of: :step_run, dependent: :destroy
  has_one :external_build, inverse_of: :step_run, dependent: :destroy
  has_many :deployment_runs, -> { includes(:deployment).merge(Deployment.sequential) }, inverse_of: :step_run, dependent: :destroy
  has_many :deployments, through: :step
  has_many :running_deployments, through: :deployment_runs, source: :deployment

  validates :step_id, uniqueness: {scope: :commit_id}

  after_commit -> { update(build_notes_raw: relevant_changes) }, on: :create
  # FIXME: solve this correctly, we rely on wait time to ensure steps are triggered in correct order
  after_commit -> { Releases::TriggerWorkflowRunJob.set(wait: BASE_WAIT_TIME * step_number).perform_later(id) }, on: :create
  after_commit -> { create_stamp!(data: stamp_data) }, on: :create

  STAMPABLE_REASONS = %w[
    created
    ci_triggered
    ci_retriggered
    ci_workflow_unavailable
    ci_finished
    ci_workflow_failed
    ci_workflow_halted
    build_available
    build_unavailable
    build_not_found_in_store
    build_found_in_store
    deployment_restarted
    finished
    failed_with_action_required
  ]

  # TODO: deprecate this
  STAMPABLE_REASONS.concat(["status_changed"])

  STATES = {
    on_track: "on_track",
    ci_workflow_triggered: "ci_workflow_triggered",
    ci_workflow_unavailable: "ci_workflow_unavailable",
    ci_workflow_started: "ci_workflow_started",
    ci_workflow_failed: "ci_workflow_failed",
    ci_workflow_halted: "ci_workflow_halted",
    build_ready: "build_ready",
    build_found_in_store: "build_found_in_store",
    build_not_found_in_store: "build_not_found_in_store",
    build_available: "build_available",
    build_unavailable: "build_unavailable",
    deployment_started: "deployment_started",
    deployment_failed: "deployment_failed",
    success: "success",
    cancelling: "cancelling",
    cancelled: "cancelled",
    cancelled_before_start: "cancelled_before_start",
    failed_with_action_required: "failed_with_action_required",
    deployment_restarted: "deployment_restarted"
  }

  END_STATES = STATES.slice(
    :ci_workflow_unavailable,
    :ci_workflow_failed,
    :ci_workflow_halted,
    :build_unavailable,
    :build_not_found_in_store,
    :deployment_failed,
    :success,
    :cancelled,
    :cancelled_before_start
  ).keys

  WORKFLOW_NOT_STARTED = [:on_track]
  WORKFLOW_IN_PROGRESS = [:ci_workflow_triggered, :ci_workflow_started]
  WORKFLOW_IMMUTABLE = STATES.keys - END_STATES - WORKFLOW_IN_PROGRESS - WORKFLOW_NOT_STARTED
  FAILED_STATES = %w[ci_workflow_failed ci_workflow_halted build_not_found_in_store build_unavailable deployment_failed failed_with_action_required cancelled_before_start]

  enum status: STATES

  aasm safe_state_machine_params do
    state :on_track, initial: true
    state(*STATES.keys)

    event :trigger_ci, after_commit: :after_trigger_ci do
      transitions from: :on_track, to: :ci_workflow_triggered
    end

    event :ci_start, after_commit: -> { WorkflowProcessors::WorkflowRunJob.perform_later(id) } do
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

    event(:retry_ci, after_commit: :after_retrigger_ci) do
      before :retry_workflow_run
      transitions from: [:ci_workflow_failed, :ci_workflow_halted], to: :ci_workflow_started
    end

    event(:finish_ci, after_commit: :after_finish_ci) { transitions from: :ci_workflow_started, to: :build_ready }
    event(:build_found, after_commit: :trigger_deployment) { transitions from: :build_ready, to: :build_found_in_store }

    event(:upload_artifact, after_commit: :after_artifact_uploaded) do
      before { add_build_artifact(artifacts_url) }
      transitions from: :build_ready, to: :build_available
    end

    event(:build_not_found, after_commit: -> { notify_on_failure!("Build not found in store!") }) do
      transitions from: :build_ready, to: :build_not_found_in_store
    end
    event(:build_upload_failed) { transitions from: :build_ready, to: :build_unavailable }
    event(:start_deploy) { transitions from: [:build_available, :build_found_in_store, :build_ready], to: :deployment_started }
    event(:restart_deploy, after_commit: :resume_deployments) do
      transitions from: [:failed_with_action_required], to: :deployment_restarted
    end

    event(:fail_deploy) do
      transitions from: [:deployment_started, :deployment_restarted], to: :deployment_failed
    end

    event :fail_deployment_with_sync_option, after_commit: :after_manual_submission_required do
      transitions from: [:deployment_started, :deployment_restarted], to: :failed_with_action_required
    end

    event(:finish) do
      after { event_stamp!(reason: :finished, kind: :success, data: stamp_data) }
      after { finalize_release }
      transitions from: [:deployment_started, :deployment_restarted], to: :success
    end

    event(:cancel, after_commit: -> { Releases::CancelWorkflowRunJob.perform_later(id) }) do
      transitions from: WORKFLOW_IMMUTABLE, to: :cancelled
      transitions from: WORKFLOW_IN_PROGRESS, to: :cancelling
      transitions from: WORKFLOW_NOT_STARTED, to: :cancelled_before_start
    end
  end

  enum approval_status: {pending: "pending", approved: "approved", rejected: "rejected"}, _prefix: "approval"

  attr_accessor :current_user
  attr_accessor :artifacts_url

  delegate :release_platform, :release, :platform, to: :release_platform_run
  delegate :release_branch, :release_version, to: :release
  delegate :train, :store_provider, to: :release_platform
  delegate :app, :unzip_artifact?, :notify!, to: :train
  delegate :organization, to: :app
  delegate :commit_hash, to: :commit
  delegate :download_url, to: :build_artifact
  delegate :ci_cd_provider, :workflow_id, :workflow_name, :step_number, :build_artifact_name_pattern, :has_uploadables?, :has_findables?, :name, :app_variant, to: :step
  scope :not_failed, -> { where.not(status: FAILED_STATES) }
  scope :sequential, -> { order("step_runs.scheduled_at ASC") }

  def basic_build_version
    build_version.split("-").first
  end

  def after_manual_submission_required
    event_stamp!(reason: :failed_with_action_required, kind: :error, data: stamp_data)
    notify_on_failure!("manual submission required!")
  end

  def build_size
    build_artifact&.file_size_in_mb
  end

  # TODO: move these explicit state checks to use a constant, perhaps END_STATES
  def active?
    release_platform_run.on_track? && !cancelled? && !success? && !status.in?(FAILED_STATES)
  end

  def find_build
    store_provider.find_build(build_number)
  end

  def get_workflow_run
    ci_cd_provider.get_workflow_run(ci_ref)
  end

  def get_build_artifact(artifacts_url)
    ci_cd_provider.get_artifact(artifacts_url, build_artifact_name_pattern)
  end

  def fetching_build?
    may_finish_ci? && build_artifact.blank?
  end

  def build_artifact_available?
    build_artifact.present?
  end

  def startable_deployment?(deployment)
    return false unless active?
    return true if deployment.first? && deployment_runs.empty?

    next_deployment == deployment
  end

  def manually_startable_deployment?(deployment)
    return false if deployment.first?
    return false if step.review?
    startable_deployment?(deployment) && (last_deployment_run&.released? || release_platform_run.patch_fix? || release.hotfix?)
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

  def in_progress?
    on_track? || ci_workflow_triggered? || ci_workflow_started? || build_ready? || deployment_started? || deployment_restarted?
  end

  def blocked?
    ci_workflow_failed? || ci_workflow_halted? || failed_with_action_required?
  end

  def failed?
    build_unavailable? || ci_workflow_unavailable? || deployment_failed?
  end

  def done?
    success?
  end

  def status_summary
    {
      in_progress: in_progress?,
      done: done?,
      failed: failed?
    }
  end

  def first_deployment
    step.deployments.order(deployment_number: :asc).first
  end

  def finished_deployments?
    deployment_runs.released.size == step.deployments.size
  end

  def finish_deployment!(deployment)
    return finish! if finished_deployments? || deployment.next.blank?
    return if deployment.next.production_channel?
    return unless step.auto_deploy?

    # trigger the next deployment if available
    trigger_deployment(deployment.next)
  end

  def fail_deployment!(deployment)
    return if deployment.next

    fail_deploy!
  end

  def trigger_deployment(deployment = first_deployment)
    Triggers::Deployment.call(step_run: self, deployment: deployment)
  end

  def resume_deployments
    event_stamp!(reason: :deployment_restarted, kind: :notice, data: stamp_data)
    failed_deployment_run = deployment_runs.failed_with_action_required.sole
    failed_deployment_run.skip!
  end

  def notification_params
    step.notification_params
      .merge(release_platform_run.notification_params)
      .merge(
        {
          ci_link: ci_link,
          build_number: build_number,
          commit_sha: commit.short_sha,
          commit_message: commit.message,
          commit_url: commit.url,
          artifact_download_link: build_artifact&.download_url,
          build_notes: build_notes,
          manual_submission_required: status == STATES[:failed_with_action_required]
        }
      )
  end

  def production_release_happened?
    deployment_runs
      .not_failed
      .any?(&:production_release_happened?)
  end

  def production_release_submitted?
    deployment_runs
      .not_failed
      .any?(&:production_release_submitted?)
  end

  def relevant_changes
    previous_step_run = release_platform_run.previous_successful_run_before(self)

    changelog_commits = release.release_changelog&.commit_messages(organization.merge_only_build_notes?)
    commits_before = release_platform_run
      .commits_between(previous_step_run, self)
      .commit_messages(organization.merge_only_build_notes?)

    return commits_before if previous_step_run.present?

    (changelog_commits || []) + (commits_before || [])
  end

  def build_notes
    build_notes_raw
      .map { |str| str&.strip }
      .flat_map { |line| train.compact_build_notes? ? line.split("\n").first : line.split("\n") }
      .map { |line| line.gsub(/\p{Emoji_Presentation}\s*/, "") }
      .reject { |line| line =~ /\AMerge|\ACo-authored-by|\A---------/ }
      .compact_blank
      .uniq
      .map { |str| "• #{str}" }
      .join("\n").presence || "Nothing new"
  end

  def cancel_ci_workflow!
    ci_cd_provider.cancel_workflow_run!(ci_ref)
  end

  def workflow_found?
    ci_ref.present?
  end

  def find_and_update_workflow_run
    return if workflow_found?
    find_workflow_run.then { |wr| update_ci_metadata!(wr) }
  end

  def trigger_ci_worfklow_run!
    trigger_workflow_run
    trigger_ci!
  end

  def release_info
    slice(:build_version, :build_number, :updated_at, :platform)
  end

  def sync_store_status!
    return unless failed_with_action_required?
    restart_deploy! if store_provider.build_present_in_public_track?(build_number)
  end

  def build_display_name
    "#{build_version} (#{build_number})"
  end

  private

  def previous_step_run
    release_platform_run
      .step_runs_for(step)
      .where("scheduled_at < ?", scheduled_at)
      .where.not(id: id)
      .order(:scheduled_at)
      .last
  end

  def find_workflow_run
    ci_cd_provider.find_workflow_run(workflow_id, release_branch, commit_hash)
  end

  def update_ci_metadata!(workflow_run)
    return if workflow_run.try(:[], :ci_ref).blank?
    update!(ci_ref: workflow_run[:ci_ref], ci_link: workflow_run[:ci_link])
  end

  def trigger_workflow_run(retrigger: false)
    update_build_number! unless retrigger

    ci_cd_provider
      .trigger_workflow_run!(workflow_id, release_branch, workflow_inputs, commit_hash)
      .then { |wr| update_ci_metadata!(wr) }
  end

  def retry_workflow_run
    return ci_cd_provider.retry_workflow_run!(ci_ref) if ci_cd_provider.workflow_retriable?
    trigger_workflow_run(retrigger: true)
  end

  def update_build_number!
    build_number = train.fixed_build_number? ? app.build_number : app.bump_build_number!
    update!(build_number:)
  end

  def workflow_inputs
    data = {version_code: build_number, build_version: build_version}
    data[:build_notes] = build_notes if organization.build_notes_in_workflow?
    data
  end

  def add_build_artifact(url)
    return if build_artifact.present?

    # FIXME: this should be passed along from the CI workflow metadata
    generated_at = Time.current

    get_build_artifact(url).with_open do |artifact_stream|
      build_build_artifact(generated_at: generated_at).save_file!(artifact_stream)
      artifact_stream.file.rewind
      self.slack_file_id = train.upload_file_for_notifications!(artifact_stream.file, build_artifact.get_filename)
    end
  end

  def stamp_data
    {
      name: step.name,
      sha: commit.short_sha,
      workflow_name:,
      version: build_version
    }
  end

  def notify_on_failure!(message)
    notify!(message, :step_failed, notification_params.merge(step_fail_reason: message))
  end

  def after_trigger_ci
    Releases::FindWorkflowRun.perform_async(id)
    event_stamp!(reason: :ci_triggered, kind: :notice, data: stamp_data)
    notify!("Step has been triggered!", :step_started, notification_params)
    Releases::CancelStepRun.perform_later(previous_step_run.id) if previous_step_run&.may_cancel?
  end

  def after_retrigger_ci
    WorkflowProcessors::WorkflowRunJob.perform_later(id)
    event_stamp!(reason: :ci_retriggered, kind: :notice, data: stamp_data)
  end

  def after_artifact_uploaded
    notify!("A new build is available!", :build_available, notification_params, slack_file_id, build_display_name) if slack_file_id
    trigger_deployment
  end

  def after_finish_ci
    return Releases::FindBuildJob.perform_async(id) if has_findables?
    return Releases::UploadArtifact.perform_async(id, artifacts_url) if has_uploadables?
    trigger_deployment
  end

  def finalize_release
    release_platform_run.finish! if release_platform_run.finalizable?
  end
end
