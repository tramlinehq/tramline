# == Schema Information
#
# Table name: workflow_runs
#
#  id                      :uuid             not null, primary key
#  artifacts_url           :string
#  external_number         :string
#  external_url            :string
#  finished_at             :datetime
#  kind                    :string           default("release_candidate"), not null
#  started_at              :datetime
#  status                  :string           not null
#  workflow_config         :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             not null, indexed
#  external_id             :string
#  pre_prod_release_id     :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class WorkflowRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  # include Sandboxable

  belongs_to :release_platform_run
  belongs_to :triggering_release, class_name: "PreProdRelease", foreign_key: "pre_prod_release_id", inverse_of: :triggered_workflow_run
  belongs_to :commit
  has_one :build, dependent: :destroy

  delegate :organization, :app, :ci_cd_provider, :train, :release_version, :release_branch, :release, :platform, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :commit_hash, to: :commit

  STAMPABLE_REASONS = %w[
    triggered
    retried
    unavailable
    failed
    halted
    finished
  ]

  KINDS = {
    release_candidate: "release_candidate",
    internal: "internal"
  }

  STATES = {
    created: "created",
    triggering: "triggering",
    triggered: "triggered",
    unavailable: "unavailable",
    started: "started",
    failed: "failed",
    halted: "halted",
    finished: "finished",
    cancelled: "cancelled",
    cancelling: "cancelling",
    cancelled_before_start: "cancelled_before_start"
  }

  NOT_STARTED = [:created]
  IN_PROGRESS = [:triggering, :triggered, :started]
  WORKFLOW_IMMUTABLE = %w[unavailable failed halted finished cancelled cancelling cancelled_before_start]
  FAILED_STATES = %w[failed halted unavailable cancelled cancelled_before_start cancelling]

  enum :status, STATES
  enum :kind, KINDS

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :initiate, after_commit: :on_initiate! do
      transitions from: :created, to: :triggering
    end

    event :initiated, after_commit: :on_initiation! do
      transitions from: :triggering, to: :triggered
    end

    event :found, after_commit: :on_found! do
      transitions from: :triggered, to: :started
    end

    event :unavailable, after_commit: :on_unavailable! do
      transitions from: [:created, :triggered], to: :unavailable
    end

    event :fail, after_commit: :on_fail! do
      transitions from: :started, to: :failed
    end

    event :halt, after_commit: :on_halt! do
      transitions from: :started, to: :halted
    end

    event :retry, after_commit: :on_retry! do
      transitions from: [:failed, :halted], to: :triggering
    end

    event :finish, after_commit: :on_finish! do
      transitions from: :started, to: :finished
    end

    event :cancel, after_commit: :on_cancel! do
      transitions from: IN_PROGRESS, to: :cancelling
      transitions from: NOT_STARTED, to: :cancelled_before_start
      transitions from: :cancelling, to: :cancelled
    end
  end

  def self.create_and_trigger!(workflow, triggering_release, commit, release_platform_run)
    workflow_run = create!(workflow_config: workflow.value,
      triggering_release:,
      release_platform_run:,
      commit:,
      kind: workflow.kind)
    workflow_run.create_build!(version_name: workflow_run.release_version, release_platform_run:, commit:)
    workflow_run.initiate!
  end

  def active?
    triggering_release.actionable? && FAILED_STATES.exclude?(status)
  end

  def find_and_update_external
    return if workflow_found?
    find_external_run.then { |wr| update_external_metadata!(wr) }
  end

  def get_external_run
    # return mock_finished_external_run if sandbox_mode?
    ci_cd_provider.get_workflow_run(external_id)
  end

  def workflow_found?
    external_id.present?
  end

  def cancel_workflow!
    return if WORKFLOW_IMMUTABLE.include?(status)

    cancel!
  end

  def cancel_external_workflow!
    return unless workflow_found?
    ci_cd_provider.cancel_workflow_run!(external_id)
  end

  def build_artifact_name_pattern
    workflow_config["artifact_name_pattern"]
  end

  def find_build
    store_provider.find_build(build.build_number)
  end

  def add_metadata!(artifacts_url:, started_at:, finished_at:)
    update!(artifacts_url:, started_at:, finished_at:)
  end

  def trigger!(retrigger: false)
    # return mock_ci_trigger if sandbox_mode?

    if retrigger
      retrigger_external_run!
    else
      update_build_number!
      trigger_external_run!
    end

    initiated!
  end

  def retrigger_external_run!
    if ci_cd_provider.workflow_retriable?
      ci_cd_provider.retry_workflow_run!(external_id)
    else
      trigger_external_run!
    end
  end

  def notification_params
    triggering_release.notification_params.merge(
      workflow_name: conf.name,
      commit_sha: commit.short_sha,
      commit_url: commit.url,
      workflow_kind: internal? ? "internal" : "RC"
    )
  end

  private

  def trigger_external_run!
    ci_cd_provider
      .trigger_workflow_run!(conf.id, release_branch, workflow_inputs, commit_hash)
      .then { |wr| update_external_metadata!(wr) }
  end

  def update_build_number!
    build.update!(build_number: app.bump_build_number!)
  end

  def workflow_inputs
    data = {version_code: build.build_number, build_version: release_version}
    data[:build_notes] = triggering_release.tester_notes if organization.build_notes_in_workflow?
    data
  end

  def update_external_metadata!(workflow_run)
    return if workflow_run.try(:[], :ci_ref).blank?

    update!(
      external_id: workflow_run[:ci_ref],
      external_url: workflow_run[:ci_link],
      external_number: workflow_run[:number]
    )
  end

  def find_external_run
    # return mock_external_run if sandbox_mode?
    ci_cd_provider.find_workflow_run(conf.id, release_branch, commit_hash)
  end

  def on_initiate!
    WorkflowRuns::TriggerJob.perform_later(id)
    event_stamp!(reason: :triggered, kind: :notice, data: stamp_data)
  end

  def on_initiation!
    return found! if workflow_found? && may_found?
    WorkflowRuns::FindJob.perform_async(id)
  end

  def on_found!
    WorkflowRuns::PollRunStatusJob.perform_later(id)
  end

  def on_retry!
    WorkflowRuns::TriggerJob.perform_later(id, retrigger: true)
    event_stamp!(reason: :retried, kind: :notice, data: stamp_data)
  end

  def on_unavailable!
    event_stamp!(reason: :unavailable, kind: :error, data: stamp_data)
    notify!("Could not find the workflow run!", :workflow_run_unavailable, notification_params)
  end

  def on_fail!
    event_stamp!(reason: :failed, kind: :error, data: stamp_data)
    notify!("The workflow run has failed!", :workflow_run_failed, notification_params)
  end

  def on_halt!
    event_stamp!(reason: :halted, kind: :error, data: stamp_data)
    notify!("The workflow run has been halted!", :workflow_run_halted, notification_params)
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: stamp_data)
    Signal.workflow_run_finished!(id)
  end

  def on_cancel!
    return unless cancelling?
    WorkflowRuns::CancelJob.perform_later(id)
  end

  def stamp_data
    {
      kind: kind.humanize,
      commit_sha: commit.short_sha,
      commit_url: commit.url,
      ref: external_number,
      url: external_url,
      version_name: release_version,
      build_number: build&.build_number
    }
  end

  def conf = ReleaseConfig::Platform::Workflow.new(workflow_config, kind)
end
