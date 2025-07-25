# == Schema Information
#
# Table name: workflow_runs
#
#  id                      :uuid             not null, primary key
#  artifacts_url           :string
#  external_number         :string
#  external_unique_number  :string
#  external_url            :string
#  finished_at             :datetime
#  kind                    :string           default("release_candidate"), not null
#  started_at              :datetime
#  status                  :string           not null
#  workflow_config         :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             not null, indexed, indexed => [pre_prod_release_id]
#  external_id             :string
#  pre_prod_release_id     :uuid             not null, indexed, indexed => [commit_id]
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

  delegate :organization, :app, :ci_cd_provider, :train, :release_branch, :release, :platform, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :commit_hash, to: :commit
  delegate :build_suffix, :artifact_name_pattern, to: :conf

  STAMPABLE_REASONS = %w[
    triggered
    retried
    unavailable
    failed
    halted
    finished
    trigger_failed
  ]

  KINDS = {
    release_candidate: "release_candidate",
    internal: "internal"
  }

  STATES = {
    created: "created",
    triggering: "triggering",
    triggered: "triggered",
    trigger_failed: "trigger_failed",
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
  WORKFLOW_IMMUTABLE = %w[unavailable failed halted finished cancelled cancelling cancelled_before_start trigger_failed]
  FAILED_STATES = %w[failed halted unavailable cancelled cancelled_before_start cancelling trigger_failed]

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
      transitions from: [:failed, :triggered], to: :started
    end

    event :unavailable, after_commit: :on_unavailable! do
      transitions from: [:created, :triggered, :triggering], to: :unavailable
    end

    # this is when the actual workflow run has failed (exit 1)
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

    event :trigger_failed, after_commit: :on_trigger_fail! do
      transitions from: :triggering, to: :trigger_failed
    end
  end

  def self.create_and_trigger!(workflow_config, triggering_release, commit, release_platform_run)
    workflow_run = create!(workflow_config: workflow_config.as_json,
      triggering_release:,
      release_platform_run:,
      commit:,
      kind: workflow_config.kind)
    workflow_run.create_build!(release_platform_run:, commit:)
    workflow_run.initiate!
  end

  def allow_error?
    train.temporarily_allow_workflow_errors?
  end

  def active?
    triggering_release.actionable? && FAILED_STATES.exclude?(status)
  end

  def failure?
    FAILED_STATES.include?(status)
  end

  def find_and_update_external
    return if workflow_found?

    find_external_run
      .then { |external_workflow_run| check_external_data(external_workflow_run) }
      .then { |external_workflow_run| update_external_metadata!(external_workflow_run) }
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
      update_internally_managed_build_number! if app.build_number_managed_internally?
      trigger_external_run!
    end

    initiated!
  end

  def retrigger_external_run!
    if ci_cd_provider.workflow_retriable?
      ci_cd_provider
        .retry_workflow_run!(external_id)
        .then { |external_workflow_run| check_external_data(external_workflow_run) }
        .then { |external_workflow_run| update_external_metadata!(external_workflow_run) }
    elsif ci_cd_provider.workflow_retriable_in_place?
      # if the retry is in-place (the id doesn't change), we don't need to update anything for ourselves
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

  def trigger_failed_reason
    last_error = passports.where(reason: :trigger_failed, kind: :error).last
    last_error&.message
  end

  private

  class ExternalUniqueNumberNotFound < StandardError
    def initialize(message = "External unique number not found")
      super
    end

    def reason = nil
  end

  def check_external_data(external_workflow_run)
    return unless external_workflow_run.is_a?(Hash)

    if app.build_number_managed_externally?
      external_unique_number = external_workflow_run[:unique_number]
      raise ExternalUniqueNumberNotFound if external_unique_number.blank?
    end

    external_workflow_run
  end

  def trigger_external_run!
    deploy_action_enabled = organization.deploy_action_enabled? || app.deploy_action_enabled? || train.deploy_action_enabled?

    ci_cd_provider
      .trigger_workflow_run!(conf.identifier, release_branch, workflow_inputs, commit_hash, deploy_action_enabled)
      .then { |external_workflow_run| check_external_data(external_workflow_run) }
      .then { |external_workflow_run| update_external_metadata!(external_workflow_run) }
  end

  def update_internally_managed_build_number!
    build.update!(build_number: app.bump_build_number!(release_version: build.release_version))
  end

  def update_build_number_from_external_metadata!
    build.update!(build_number: external_unique_number)
    app.bump_build_number!(release_version: build.release_version, workflow_build_number: external_unique_number)
  end

  def workflow_inputs
    data = {version_code: build.build_number, build_version: build.version_name}
    data[:build_notes] = triggering_release.tester_notes if organization.build_notes_in_workflow?
    data[:parameters] = {}
    conf.parameters.each do |param|
      data[:parameters][param.name] = param.value
    end
    data
  end

  def update_external_metadata!(external_workflow_run)
    return if external_workflow_run.try(:[], :ci_ref).blank?

    update!(
      external_id: external_workflow_run[:ci_ref],
      external_url: external_workflow_run[:ci_link],
      external_number: external_workflow_run[:number],
      external_unique_number: external_workflow_run[:unique_number]
    )

    update_build_number_from_external_metadata! if app.build_number_managed_externally?
  end

  def find_external_run
    # return mock_external_run if sandbox_mode?
    ci_cd_provider.find_workflow_run(conf.identifier, release_branch, commit_hash)
  end

  def on_initiate!
    WorkflowRuns::TriggerJob.perform_async(id)
    event_stamp!(reason: :triggered, kind: :notice, data: stamp_data)
  end

  def on_initiation!
    return found! if workflow_found? && may_found?
    WorkflowRuns::FindJob.perform_async(id)
  end

  def on_found!
    WorkflowRuns::PollRunStatusJob.perform_async(id)
  end

  def on_retry!
    WorkflowRuns::TriggerJob.perform_async(id, true)
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

  def on_trigger_fail!(error)
    event_stamp!(reason: :trigger_failed, kind: :error, data: stamp_data.merge(error_message: error.message, error_reason: error.reason))
    notify!("Failed to trigger the workflow run!", :workflow_trigger_failed, notification_params)
    Signal.workflow_run_trigger_failed!(self)
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
    WorkflowRuns::CancelJob.perform_async(id)
  end

  def stamp_data
    {
      kind: kind.humanize,
      commit_sha: commit.short_sha,
      commit_url: commit.url,
      ref: external_number,
      url: external_url,
      version_name: release_platform_run.release_version,
      build_number: build&.build_number
    }
  end

  def conf = Config::Workflow.from_json(workflow_config)
end
