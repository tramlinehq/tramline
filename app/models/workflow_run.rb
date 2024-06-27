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
#  commit_id               :uuid             not null, indexed
#  external_id             :string
#  pre_prod_release_id     :bigint           not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class WorkflowRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable

  belongs_to :release_platform_run
  belongs_to :triggering_release, class_name: "PreProdRelease", foreign_key: "pre_prod_release_id", inverse_of: :workflow_run
  belongs_to :commit
  has_one :build, dependent: :destroy

  delegate :organization, :app, :ci_cd_provider, :train, :release_version, :release_branch, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :commit_hash, to: :commit

  STAMPABLE_REASONS = %w[
    ci_triggered
    ci_retriggered
    ci_workflow_unavailable
    ci_finished
    ci_workflow_failed
    ci_workflow_halted
  ]

  STATES = {
    created: "created",
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
  IN_PROGRESS = [:triggered, :started]
  TERMINAL_STATES = [:finished]
  WORKFLOW_IMMUTABLE = STATES.keys - TERMINAL_STATES - IN_PROGRESS - NOT_STARTED

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true, after_commit: :after_created
    state(*STATES.keys)

    event :trigger, after_commit: :after_trigger do
      transitions from: :created, to: :triggered
    end

    event :start, after_commit: :after_start do
      transitions from: :triggered, to: :started
    end

    event(:unavailable, after_commit: :after_unavailable) do
      transitions from: [:created, :triggered], to: :unavailable
    end

    event(:fail, after_commit: :after_fail) do
      transitions from: :started, to: :failed
    end

    event(:halt, after_commit: :after_halt) do
      transitions from: :started, to: :halted
    end

    # event(:retry, after_commit: :after_retrigger_ci) do
    #   before :retry_workflow_run
    #   transitions from: [:failed, :halted], to: :started
    # end

    event(:finish, after_commit: :after_finish) do
      transitions from: :started, to: :finished
    end

    event(:cancel, after_commit: :after_cancel) do
      transitions from: IN_PROGRESS, to: :cancelling
      transitions from: NOT_STARTED, to: :cancelled_before_start
      transitions from: :cancelling, to: :cancelled # TODO: check this
    end
  end

  def active?
    release_platform_run.on_track? && !cancelled? && !success? && !status.in?(FAILED_STATES)
  end

  def find_and_update_external
    return if workflow_found?
    find_external_run.then { |wr| update_external_metadata!(wr) }
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
    update!(artifacts_url:, started_at:, finished_at:)
  end

  def trigger_external_run!(retrigger: false)
    update_build_number! unless retrigger

    ci_cd_provider
      .trigger_workflow_run!(workflow_id, release_branch, workflow_inputs, commit_hash)
      .then { |wr| update_external_metadata!(wr) }

    trigger!
  end

  private

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

  def update_external_metadata!(workflow_run)
    return if workflow_run.try(:[], :ci_ref).blank?

    update!(
      external_id: workflow_run[:ci_ref],
      external_url: workflow_run[:ci_link],
      external_number: workflow_run[:number]
    )
  end

  def find_external_run
    ci_cd_provider.find_workflow_run(workflow_id, release_branch, commit_hash)
  end

  def after_created
    WorkflowRuns::TriggerJob.perform_later(id)
  end

  def after_trigger
    event_stamp!(reason: :ci_triggered, kind: :notice, data: stamp_data)
    # FIXME: notify triggered
    # notify!("Step has been triggered!", :step_started, notification_params)
    # FIXME Releases::CancelStepRun.perform_later(previous_step_run.id) if previous_step_run&.may_cancel?

    return start! if workflow_found? && may_start?
    WorkflowRuns::FindJob.perform_async(id)
  end

  def after_start
    WorkflowRuns::PollRunStatusJob.perform_later(id)
  end

  def after_unavailable
    # FIXME: notify unavailable
    # notify_on_failure!("Could not find the CI workflow!")
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
    Coordinators::Signals.workflow_run_finished!(self, triggering_release)
  end

  def after_cancel
    WorkflowRuns::CancelJob.perform_later(id)
  end

  def stamp_data
    {
      ref: external_id,
      url: external_url,
      version: build_number
    }
  end
end
