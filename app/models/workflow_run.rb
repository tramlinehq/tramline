# == Schema Information
#
# Table name: workflow_runs
#
#  id                      :uuid             not null, primary key
#  artifacts_url           :string
#  build_number            :string
#  external_number         :string
#  external_url            :string
#  finished_at             :datetime
#  started_at              :datetime
#  status                  :string           not null
#  workflow_config         :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  external_id             :string
#  pre_prod_release_id     :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class WorkflowRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable

  belongs_to :release_platform_run
  belongs_to :pre_prod_release
  belongs_to :commit
  has_one :build, dependent: :destroy

  delegate :organization, :app, :ci_cd_provider, :train, :release_version, :release_branch, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :commit_hash, to: :commit
  delegate :has_findables?, :has_uploadables?, :store_provider, to: :pre_prod_release

  STAMPABLE_REASONS = %w[
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
  ]

  STATES = {
    created: "created",
    triggered: "triggered",
    unavailable: "unavailable",
    started: "started",
    failed: "failed",
    halted: "halted",
    build_ready: "build_ready",
    build_found_in_store: "build_found_in_store",
    build_not_found_in_store: "build_not_found_in_store",
    build_unavailable: "build_unavailable",
    build_available: "build_available",
    cancelled: "cancelled",
    cancelling: "cancelling",
    cancelled_before_start: "cancelled_before_start"
  }

  NOT_STARTED = [:created]
  IN_PROGRESS = [:triggered, :started]
  TERMINAL_STATES = [:build_found_in_store, :build_not_found_in_store, :build_unavailable, :build_available]
  WORKFLOW_IMMUTABLE = STATES.keys - TERMINAL_STATES - WORKFLOW_IN_PROGRESS - WORKFLOW_NOT_STARTED

  aasm safe_state_machine_params do
    state :created, initial: true, after_commit: :trigger
    state(*STATES.keys)

    event :trigger, after_commit: :after_trigger do
      before :trigger_workflow_run
      transitions from: :created, to: :triggered
    end

    event :start, after_commit: -> { WorkflowProcessors::WorkflowRunJob.perform_later(id) } do
      transitions from: :triggered, to: :started
    end

    event(:unavailable, after_commit: -> { notify_on_failure!("Could not find the CI workflow!") }) do
      transitions from: [:created, :triggered], to: :unavailable
    end

    event(:fail, after_commit: :after_fail) do
      transitions from: :started, to: :failed
    end

    event(:halt, after_commit: :after_halt) do
      transitions from: :started, to: :halted
    end

    event(:retry, after_commit: :after_retrigger_ci) do
      before :retry_workflow_run
      transitions from: [:failed, :halted], to: :started
    end

    event(:finish, after_commit: :after_finish) do
      transitions from: :started, to: :build_ready
    end

    event(:build_found, before: :create_build_without_artifact!, after_commit: :after_build_create) do
      transitions from: :build_ready, to: :build_available
    end

    event(:upload_artifact, before: :create_build_with_artifact!, after_commit: :after_build_create) do
      transitions from: :build_ready, to: :build_available
    end

    event(:build_not_found, after_commit: :after_build_not_found) do
      transitions from: :build_ready, to: :build_not_found_in_store
    end

    event(:build_upload_failed, after_commit: :after_build_upload_failed) do
      transitions from: :build_ready, to: :build_unavailable
    end

    event(:cancel, after_commit: -> { WorkflowRuns::CancelJob.perform_later(id) }) do
      transitions from: WORKFLOW_IN_PROGRESS, to: :cancelling
      transitions from: WORKFLOW_NOT_STARTED, to: :cancelled_before_start
      transitions from: :cancelling, to: :cancelled # TODO: check this
    end
  end

  def active?
    release_platform_run.on_track? && !cancelled? && !success? && !status.in?(FAILED_STATES)
  end

  def find_and_update_external
    return if workflow_found?
    find_external_run.then { |wr| update_ci_metadata!(wr) }
  end

  def get_external_run
    ci_cd_provider.get_workflow_run(external_id)
  end

  def workflow_found?
    external_id.present?
  end

  def cancel_workflow!
    return unless workflow_found?
    ci_cd_provider.cancel_workflow_run!(external_id)
  end

  def build_artifact_name_pattern
    workflow_config["artifact_name_pattern"]
  end

  def find_build
    store_provider.find_build(build_number)
  end

  def add_metadata!(artifacts_url:, started_at:, finished_at:)
    update!(artifacts_url:, started_at:, finished_at:, external_number: number)
  end

  private

  def trigger_workflow_run(retrigger: false)
    update_build_number! unless retrigger

    ci_cd_provider
      .trigger_workflow_run!(workflow_id, release_branch, workflow_inputs, commit_hash)
      .then { |wr| update_ci_metadata!(wr) }
  end

  def update_build_number!
    build_number = train.fixed_build_number? ? app.build_number : app.bump_build_number!
    update!(build_number:)
  end

  def workflow_inputs
    data = {version_code: build_number, build_version: release_version}
    data[:build_notes] = build_notes if organization.build_notes_in_workflow?
    data
  end

  def workflow_id
    workflow_config["id"]
  end

  # FIXME: this is a temporary solution to get the build notes
  def build_notes
    "TODO: add these"
  end

  def update_ci_metadata!(workflow_run)
    return if workflow_run.try(:[], :ci_ref).blank?
    update!(
      external_id: workflow_run[:ci_ref],
      external_link: workflow_run[:ci_link],
      external_number: workflow_run[:number]
    )
  end

  def find_external_run
    ci_cd_provider.find_workflow_run(workflow_id, release_branch, commit_hash)
  end

  def after_trigger
    WorkflowRuns::FindJob.perform_async(id)
    event_stamp!(reason: :ci_triggered, kind: :notice, data: stamp_data)
    notify!("Step has been triggered!", :step_started, notification_params)
    # FIXME Releases::CancelStepRun.perform_later(previous_step_run.id) if previous_step_run&.may_cancel?
  end

  def after_fail
    event_stamp!(reason: :ci_workflow_failed, kind: :error, data: stamp_data)
    # FIXME: notify failure
  end

  def after_halt
    event_stamp!(reason: :ci_workflow_halted, kind: :error, data: stamp_data)
    # FIXME: notify halt
  end

  def after_finish
    event_stamp!(reason: :ci_finished, kind: :success, data: stamp_data)

    return WorkflowRuns::FindBuildJob.perform_async(id) if has_findables?
    WorkflowRuns::UploadArtifactJob.perform_async(id) if has_uploadables?
  end

  def after_build_not_found
    event_stamp!(reason: :build_not_found_in_store, kind: :error, data: stamp_data)
    # FIXME: notify build not found
  end

  def after_build_upload_failed
    event_stamp!(reason: :build_unavailable, kind: :error, data: stamp_data)
    # FIXME: notify build upload failed
  end

  def get_build_artifact
    ci_cd_provider.get_artifact_v2(artifacts_url, build_artifact_name_pattern)
  end

  def create_build_without_artifact!
    return if build.present?

    create_build!(
      release_platform_run:,
      sequence_number: release_platform_run.next_build_sequence_number,
      generated_at: finished_at
    )
  end

  def create_build_with_artifact!
    return if build.present?
    return if artifacts_url.blank?

    get_build_artifact => { artifact:, stream: }
    build = Build.new(
      workflow_run: self,
      release_platform_run:,
      sequence_number: release_platform_run.next_build_sequence_number,
      generated_at: artifact[:generated_at] || finished_at,
      size_in_bytes: artifact[:size_in_bytes],
      external_name: artifact[:name],
      external_id: artifact[:id]
    )

    stream.with_open do |artifact_stream|
      build.build_artifact.save_file!(artifact_stream)
      artifact_stream.file.rewind
      build.slack_file_id = train.upload_file_for_notifications!(artifact_stream.file, build.build_artifact.get_filename)
    end

    build.save!
  end

  def after_build_create
    pre_prod_release.attach_build!(build)
  end

  def stamp_data
    {
      ref: external_id,
      url: external_link,
      version: build_number
    }
  end
end
