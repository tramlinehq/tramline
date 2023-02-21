# == Schema Information
#
# Table name: deployment_runs
#
#  id                         :uuid             not null, primary key
#  initial_rollout_percentage :decimal(8, 5)
#  scheduled_at               :datetime         not null
#  status                     :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  deployment_id              :uuid             not null, indexed => [train_step_run_id]
#  train_step_run_id          :uuid             not null, indexed => [deployment_id], indexed
#
class DeploymentRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Loggable

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  has_one :external_build, dependent: :destroy
  has_one :staged_rollout, dependent: :destroy

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}

  delegate :step,
    :release,
    :commit,
    :build_number,
    :build_artifact,
    :build_version,
    to: :step_run
  delegate :external?,
    :google_play_store_integration?,
    :slack_integration?,
    :app_store_integration?,
    :store?,
    :deployment_number,
    :integration,
    :deployment_channel,
    :deployment_channel_name,
    :staged_rollout?,
    :staged_rollout_config,
    to: :deployment
  delegate :app, to: :step
  delegate :ios?, to: :app
  delegate :release_version, to: :release

  scope :for_ids, ->(ids) { includes(deployment: :integration).where(id: ids) }

  STAMPABLE_REASONS = [
    "created",
    "bundle_identifier_not_found",
    "invalid_package",
    "apks_are_not_allowed",
    "upload_failed_reason_unknown",
    "release_failed",
    "released"
  ]

  STATES = {
    created: "created",
    started: "started",
    submitted: "submitted",
    uploaded: "uploaded",
    upload_failed: "upload_failed",
    rollout_started: "rollout_started",
    released: "released",
    failed: "failed"
  }

  enum status: STATES

  # FIXME: write functions/events that are not tied to one particular store
  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { step_run.startable_deployment?(deployment) }
    state(*STATES.keys)

    event :dispatch, after_commit: :after_dispatch do
      after { step_run.start_deploy! if first? }
      transitions from: :created, to: :started
    end

    event(:submit, guard: :ios?, after_commit: :locate_external_build) do
      transitions from: :started, to: :submitted
    end

    event :upload, after_commit: -> { Deployments::ReleaseJob.perform_later(id) } do
      transitions from: :started, to: :uploaded
    end

    event :upload_fail do
      after { step_run.fail_deploy! }
      transitions from: :started, to: :upload_failed
    end

    event :start_rollout, guard: :staged_rollout? do
      after { rollout! }
      transitions from: :uploaded, to: :rollout_started
    end

    event :dispatch_fail, after_commit: -> { event_stamp!(reason: :release_failed, kind: :error, data: stamp_data) } do
      after { step_run.fail_deploy! }
      transitions from: [:uploaded, :submitted, :rollout_started], to: :failed
    end

    event :complete, after_commit: -> { event_stamp!(reason: :released, kind: :success, data: stamp_data) } do
      after { step_run.finish_deployment!(deployment) }
      transitions from: [:created, :uploaded, :started, :submitted, :rollout_started], to: :released
    end
  end

  scope :matching_runs_for, ->(integration) { includes(:deployment).where(deployments: {integration: integration}) }
  scope :has_begun, -> { where.not(status: :created) }

  after_commit -> { create_stamp!(data: stamp_data) }, on: :create

  def first?
    step_run.deployment_runs.first == self
  end

  ExternalBuildNotInTerminalState = Class.new(StandardError)

  def locate_external_build(attempt: 1, wait: 1.second)
    Deployments::AppStoreConnect::UpdateExternalBuildJob.set(wait: wait).perform_later(id, attempt:)
  end

  def update_external_build
    build_info = provider.find_build(build_number)
    (external_build || build_external_build).update(build_info.attributes)

    GitHub::Result.new do
      if build_info.success?
        complete!
      elsif build_info.failed?
        dispatch_fail!
      else
        raise ExternalBuildNotInTerminalState, "Retrying in some time..."
      end
    end
  end

  def release_to_testflight!
    return unless app_store_integration?
    provider.release_to_testflight(deployment_channel, build_number)
    submit!
  end

  def start_distribution!
    return unless store? && app_store_integration?
    Deployments::AppStoreConnect::TestFlightReleaseJob.perform_later(id)
  end

  def start_release!
    return unless store?
    return start_rollout! if staged_rollout?
    fully_release_to_playstore! if google_play_store_integration?
  end

  def fully_release_to_playstore!
    release_with(rollout_value: Deployment::FULL_ROLLOUT_VALUE) do |result|
      if result.ok?
        complete!
      else
        dispatch_fail!
        elog(result.error)
      end
    end
  end

  def rollout!
    release_with(is_draft: true) do |result|
      if result.ok?
        create_staged_rollout!(config: staged_rollout_config)
      else
        dispatch_fail!
        elog(result.error)
      end
    end
  end

  def release_with(rollout_value: nil, is_draft: false)
    raise ArgumentError, "cannot have a rollout for a draft release" if is_draft && rollout_value.present?

    release.with_lock do
      return unless promotable?

      if is_draft
        yield provider.create_draft_release(deployment_channel, build_number, release_version)
      else
        yield provider.rollout_release(deployment_channel, build_number, release_version, rollout_value)
      end
    end
  end

  def halt_release_in_playstore!(rollout_value:)
    raise ArgumentError, "cannot halt without a rollout value" if rollout_value.blank?

    release.with_lock do
      return unless rollout_started?

      yield provider.halt_release(deployment_channel, build_number, release_version, rollout_value)
    end
  end

  def upload_to_playstore!
    return unless google_play_store_integration?

    with_lock do
      return if uploaded?

      build_artifact.with_open do |file|
        result = provider.upload(file)
        if result.ok?
          upload!
        else
          upload_fail!
          reason = GooglePlayStoreIntegration::DISALLOWED_ERRORS_WITH_REASONS.fetch(result.error.class, :upload_failed_reason_unknown)
          event_stamp!(reason:, kind: :error, data: stamp_data)
          elog(result.error)
        end
      end
    end
  end

  def push_to_slack!
    return unless slack_integration?

    with_lock do
      return if released?
      provider.deploy!(deployment_channel, {step_run: step_run})
      complete!
    end
  end

  def has_uploaded?
    uploaded? || failed? || released?
  end

  # FIXME: should we take a lock around this SR? what is someone double triggers the run?
  def start_upload!
    if store? && step_run.similar_deployment_runs_for(self).any?(&:has_uploaded?)
      return upload!
    end

    return Deployments::GooglePlayStore::Upload.perform_later(id) if google_play_store_integration?
    Deployments::Slack.perform_later(id) if slack_integration?
  end

  def promotable?
    release.on_track? && store? && (uploaded? || rollout_started?)
  end

  def rolloutable?
    step.release? && promotable? && deployment.staged_rollout? && rollout_started?
  end

  def rollout_percentage
    return unless google_play_store_integration?
    return staged_rollout.last_rollout_percentage if staged_rollout?
    initial_rollout_percentage || Deployment::FULL_ROLLOUT_VALUE
  end

  private

  def provider
    integration.providable
  end

  def stamp_data
    {
      version: build_version,
      chan: deployment_channel_name,
      provider: integration&.providable&.display,
      file: build_artifact&.get_filename
    }
  end

  def after_dispatch
    return complete! if external?
    return start_distribution! if ios?
    start_upload!
  end
end
