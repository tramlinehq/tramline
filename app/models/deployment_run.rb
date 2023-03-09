# == Schema Information
#
# Table name: deployment_runs
#
#  id                         :uuid             not null, primary key
#  failure_reason             :string
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
  using RefinedArray

  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs
  belongs_to :deployment, inverse_of: :deployment_runs
  has_one :staged_rollout, dependent: :destroy
  has_one :external_release, dependent: :destroy

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}

  delegate :step,
    :release,
    :commit,
    :build_number,
    :build_artifact,
    :build_version,
    to: :step_run
  delegate :deployment_number,
    :integration,
    :deployment_channel,
    :deployment_channel_name,
    :external?,
    :google_play_store_integration?,
    :slack_integration?,
    :app_store_integration?,
    :store?,
    :production_channel?,
    :staged_rollout?,
    :staged_rollout_config,
    to: :deployment
  delegate :release_version, to: :release
  delegate :app, to: :release

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
    prepared_release: "prepared_release",
    submitted_for_review: "submitted_for_review",
    uploaded: "uploaded",
    ready_to_release: "ready_to_release",
    rollout_started: "rollout_started",
    released: "released",
    upload_failed: "upload_failed", # TODO: migrate to failure_reason
    failed: "failed"
  }

  enum status: STATES
  enum failure_reason: {
    unknown_failure: "unknown_failure"
  }.merge(Installations::Apple::AppStoreConnect::Error.reasons.zip_map_self)

  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { step_run.startable_deployment?(deployment) }
    state(*STATES.keys)

    event :dispatch, after_commit: :kickoff! do
      after { step_run.start_deploy! if first? }
      transitions from: :created, to: :started
    end

    event(:prepare_release, guards: [:app_store_integration?, :production_channel?]) do
      transitions from: :started, to: :prepared_release
    end

    event(:submit_for_review, after_commit: :find_submission) do
      transitions from: [:started, :prepared_release], to: :submitted_for_review
    end

    event :upload, after_commit: -> { Deployments::ReleaseJob.perform_later(id) } do
      transitions from: :started, to: :uploaded
    end

    event :upload_fail do
      after { step_run.fail_deploy! }
      transitions from: :started, to: :upload_failed
    end

    event :ready_to_release, after_commit: -> { external_release.update(reviewed_at: Time.current) } do
      transitions from: :submitted_for_review, to: :ready_to_release
    end

    event :engage_release do
      transitions from: [:uploaded, :ready_to_release], to: :rollout_started
    end

    event :dispatch_fail, before: :set_reason, after_commit: :release_failed do
      transitions from: [:started, :uploaded, :submitted_for_review, :ready_to_release, :rollout_started], to: :failed
      after { step_run.fail_deploy! }
    end

    event :complete, after_commit: :release_success do
      after { step_run.finish_deployment!(deployment) }
      transitions from: [:created, :uploaded, :started, :submitted_for_review, :rollout_started, :ready_to_release], to: :released
    end
  end

  scope :for_ids, ->(ids) { includes(deployment: :integration).where(id: ids) }
  scope :matching_runs_for, ->(integration) { includes(:deployment).where(deployments: {integration: integration}) }
  scope :has_begun, -> { where.not(status: :created) }

  after_commit -> { create_stamp!(data: stamp_data) }, on: :create

  def first?
    step_run.deployment_runs.first == self
  end

  def find_submission
    Deployments::AppStoreConnect::UpdateExternalReleaseJob.perform_async(id)
  end

  def kickoff!
    return complete! if external?
    return Deployments::SlackJob.perform_later(id) if slack_integration?
    return Deployments::AppStoreConnect::Release.kickoff!(self) if app_store_integration?
    kickoff_upload_on_play_store! if google_play_store_integration?
  end

  ## play store
  #
  def kickoff_upload_on_play_store!
    return upload! if step_run.similar_deployment_runs_for(self).any?(&:has_uploaded?)
    Deployments::GooglePlayStore::Upload.perform_later(id)
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

          reason =
            GooglePlayStoreIntegration::DISALLOWED_ERRORS_WITH_REASONS
              .fetch(result.error.class, :upload_failed_reason_unknown)

          event_stamp!(reason:, kind: :error, data: stamp_data)
          elog(result.error)
        end
      end
    end
  end

  def start_release!
    return unless store?

    if google_play_store_integration?
      if staged_rollout?
        engage_release!
        rollout_to_playstore!
      else
        fully_release_to_playstore!
      end
    end

    Deployments::AppStoreConnect::Release.start_release!(self) if app_store_integration?
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

  def halt_release_in_playstore!(rollout_value:)
    raise ArgumentError, "cannot halt without a rollout value" if rollout_value.blank?

    release.with_lock do
      return unless rollout_started?
      yield provider.halt_release(deployment_channel, build_number, release_version, rollout_value)
    end
  end

  def rollout_to_playstore!
    release_with(is_draft: true) do |result|
      if result.ok?
        create_staged_rollout!(config: staged_rollout_config)
      else
        dispatch_fail!
        elog(result.error)
      end
    end
  end

  # TODO: handle known errors gracefully and show to users
  def release_with(rollout_value: nil, is_draft: false)
    raise ArgumentError, "cannot have a rollout for a draft deployments" if is_draft && rollout_value.present?

    release.with_lock do
      return unless promotable?

      if is_draft
        yield provider.create_draft_release(deployment_channel, build_number, release_version)
      else
        yield provider.rollout_release(deployment_channel, build_number, release_version, rollout_value)
      end
    end
  end

  def promotable?
    release.on_track? && store? && (uploaded? || rollout_started?)
  end

  def rolloutable?
    step.release? &&
      promotable? &&
      deployment.staged_rollout? &&
      rollout_started?
  end

  def controllable_rollout?
    rolloutable? && deployment.controllable_rollout?
  end

  def app_store_release?
    step.release? &&
      release.on_track? &&
      app_store_integration? &&
      production_channel?
  end

  def test_flight_release?
    release.on_track? && app_store_integration? && !production_channel?
  end

  def reviewable?
    app_store_release? && may_submit_for_review?
  end

  def releasable?
    app_store_release? && may_engage_release?
  end

  def rollout_percentage
    return unless google_play_store_integration?
    return staged_rollout.last_rollout_percentage if staged_rollout?
    initial_rollout_percentage || Deployment::FULL_ROLLOUT_VALUE
  end

  def has_uploaded?
    uploaded? || failed? || released?
  end

  ## slack
  #
  def push_to_slack!
    return unless slack_integration?

    with_lock do
      return if released?
      provider.deploy!(deployment_channel, {step_run: step_run})
      complete!
    end
  end

  def provider
    integration.providable
  end

  def fail_with_error(error)
    elog(error)
    if error.is_a?(Installations::Error)
      dispatch_fail!(reason: error.reason)
    else
      dispatch_fail!
    end
  end

  private

  def set_reason(args = nil)
    self.failure_reason = args&.fetch(:reason, :unknown_failure)
  end

  def release_failed
    event_stamp!(reason: :release_failed, kind: :error, data: stamp_data)
  end

  def release_success
    if external_release
      now = Time.current
      external_release.update(released_at: now, reviewed_at: external_release.reviewed_at.presence || now)
    end

    event_stamp!(reason: :released, kind: :success, data: stamp_data)
  end

  def stamp_data
    {
      version: build_version,
      chan: deployment_channel_name,
      provider: integration&.providable&.display,
      file: build_artifact&.get_filename
    }
  end
end
