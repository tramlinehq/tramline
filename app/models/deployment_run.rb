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
#  deployment_id              :uuid             not null, indexed => [step_run_id]
#  step_run_id                :uuid             not null, indexed => [deployment_id], indexed
#
class DeploymentRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Loggable
  include Displayable
  using RefinedArray

  belongs_to :step_run, inverse_of: :deployment_runs
  belongs_to :deployment, inverse_of: :deployment_runs
  has_one :staged_rollout, dependent: :destroy
  has_one :external_release, dependent: :destroy

  validates :deployment_id, uniqueness: {scope: :step_run_id}

  delegate :step,
    :release,
    :release_platform_run,
    :commit,
    :build_number,
    :build_artifact,
    :build_version,
    to: :step_run
  delegate :deployment_number,
    :notify!,
    :integration,
    :deployment_channel,
    :deployment_channel_name,
    :external?,
    :google_play_store_integration?,
    :slack_integration?,
    :app_store_integration?,
    :app_store?,
    :test_flight?,
    :store?,
    :staged_rollout?,
    :staged_rollout_config,
    :google_firebase_integration?,
    :production_channel?,
    :release_platform,
    :internal_channel?,
    to: :deployment
  delegate :release_metadata, to: :release
  delegate :release_version, to: :release_platform_run

  STAMPABLE_REASONS = %w[
    created
    release_failed
    prepare_release_failed
    inflight_release_replaced
    submitted_for_review
    review_approved
    release_started
    released
  ]

  STATES = {
    created: "created",
    started: "started",
    prepared_release: "prepared_release",
    submitted_for_review: "submitted_for_review",
    failed_prepare_release: "failed_prepare_release",
    uploading: "uploading",
    uploaded: "uploaded",
    ready_to_release: "ready_to_release",
    rollout_started: "rollout_started",
    released: "released",
    failed: "failed"
  }

  READY_STATES = [STATES[:rollout_started], STATES[:ready_to_release]]

  enum status: STATES
  enum failure_reason: {
    review_failed: "review_failed",
    invalid_release: "invalid_release",
    unknown_failure: "unknown_failure"
  }.merge(
    *[
      Installations::Apple::AppStoreConnect::Error.reasons,
      Installations::Google::PlayDeveloper::Error.reasons,
      Installations::Google::Firebase::Error.reasons,
      Installations::Google::Firebase::OpError.reasons
    ].map(&:zip_map_self)
  )

  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { step_run.startable_deployment?(deployment) }
    state(*STATES.keys)

    event :dispatch, after_commit: :kickoff! do
      after { step_run.start_deploy! if first? }
      transitions from: :created, to: :started
    end

    event :prepare_release, guard: :app_store? do
      transitions from: [:started, :failed_prepare_release], to: :prepared_release
    end

    event :fail_prepare_release, before: :set_reason, after_commit: -> { event_stamp!(reason: :prepare_release_failed, kind: :error, data: stamp_data) } do
      transitions from: [:started, :failed_prepare_release], to: :failed_prepare_release do
        guard { |_| app_store? }
      end
    end

    event :submit_for_review, after_commit: :after_submission do
      transitions from: [:started, :prepared_release], to: :submitted_for_review
    end

    event :start_upload, after: :get_upload_status do
      transitions from: :started, to: :uploading
    end

    event :upload, after_commit: -> { Deployments::ReleaseJob.perform_later(id) } do
      transitions from: [:started, :uploading], to: :uploaded
    end

    event :ready_to_release, after_commit: :mark_reviewed do
      transitions from: :submitted_for_review, to: :ready_to_release
    end

    event :engage_release, after_commit: -> { event_stamp!(reason: :release_started, kind: :notice, data: stamp_data) } do
      transitions from: [:uploaded, :ready_to_release], to: :rollout_started
    end

    event :dispatch_fail, before: :set_reason, after_commit: :release_failed do
      transitions from: [:started, :prepared_release, :uploading, :uploaded, :submitted_for_review, :ready_to_release, :rollout_started, :failed_prepare_release], to: :failed
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
  scope :not_failed, -> { where.not(status: [:failed, :failed_prepare_release]) }
  scope :ready, -> { where(status: READY_STATES) }

  after_commit -> { create_stamp!(data: stamp_data) }, on: :create

  UnknownStoreError = Class.new(StandardError)

  def first?
    step_run.deployment_runs.first == self
  end

  def after_submission
    notify!("Submitted for review!", :submit_for_review, notification_params)
    event_stamp!(reason: :submitted_for_review, kind: :notice, data: stamp_data)
    Deployments::AppStoreConnect::UpdateExternalReleaseJob.perform_async(id)
  end

  def get_upload_status(args)
    Deployments::GoogleFirebase::UpdateUploadStatusJob.perform_async(id, args&.fetch(:op_name))
  end

  def kickoff!
    return complete! if external?
    return Deployments::SlackJob.perform_later(id) if slack_integration?
    return Deployments::AppStoreConnect::Release.kickoff!(self) if app_store_integration?
    return Deployments::GooglePlayStore::Release.kickoff!(self) if google_play_store_integration?
    Deployments::GoogleFirebase::Release.kickoff!(self) if google_firebase_integration?
  end

  def start_release!
    release_platform_run.with_lock do
      return unless release_startable?

      if google_play_store_integration?
        Deployments::GooglePlayStore::Release.start_release!(self)
      elsif app_store_integration?
        Deployments::AppStoreConnect::Release.start_release!(self)
      elsif google_firebase_integration?
        Deployments::GoogleFirebase::Release.start_release!(self)
      else
        raise UnknownStoreError
      end
    end
  end

  def on_fully_release!
    return unless store?

    release_platform_run.with_lock do
      return unless rolloutable?

      if google_play_store_integration?
        result = Deployments::GooglePlayStore::Release.release_to_all!(self)
      elsif app_store_integration?
        result = Deployments::AppStoreConnect::Release.complete_phased_release!(self)
      else
        raise UnknownStoreError
      end

      yield result
    end
  end

  def on_release(rollout_value:)
    return unless store? && google_play_store_integration?

    release_platform_run.with_lock do
      return unless controllable_rollout?

      yield Deployments::GooglePlayStore::Release.release_with(self, rollout_value:)
    end
  end

  def on_halt_release!
    return unless store?

    release_platform_run.with_lock do
      return unless rolloutable?

      if google_play_store_integration?
        result = Deployments::GooglePlayStore::Release.halt_release!(self)
      elsif app_store_integration?
        result = Deployments::AppStoreConnect::Release.halt_phased_release!(self)
      else
        raise UnknownStoreError
      end

      yield result
    end
  end

  def on_pause_release!
    return unless store? && app_store_integration?

    release_platform_run.with_lock do
      return unless automatic_rollout?

      yield Deployments::AppStoreConnect::Release.pause_phased_release!(self)
    end
  end

  def on_resume_release!
    return unless store? && app_store_integration?

    release_platform_run.with_lock do
      return unless automatic_rollout?

      yield Deployments::AppStoreConnect::Release.resume_phased_release!(self)
    end
  end

  def promotable?
    step_run.active? && store? && (uploaded? || rollout_started?)
  end

  def release_startable?
    step_run.active? && may_engage_release?
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

  def automatic_rollout?
    rolloutable? && !deployment.controllable_rollout?
  end

  def app_store_release?
    step.release? && step_run.active? && deployment.app_store?
  end

  def test_flight_release?
    step_run.active? && deployment.test_flight?
  end

  def reviewable?
    app_store_release? && prepared_release?
  end

  def releasable?
    app_store_release? && may_engage_release?
  end

  def rollout_percentage
    return unless store?
    return staged_rollout.last_rollout_percentage if staged_rollout?
    initial_rollout_percentage || Deployment::FULL_ROLLOUT_VALUE if deployment.controllable_rollout?
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
      provider.deploy!(deployment_channel, notification_params)
      complete!
    end
  end

  def provider
    integration&.providable
  end

  def fail_with_error(error)
    elog(error)
    if error.is_a?(Installations::Error)
      dispatch_fail!(reason: error.reason)
    else
      dispatch_fail!
    end
  end

  def notification_params
    deployment
      .notification_params
      .merge(step_run.notification_params)
      .merge(
        {
          project_link: external_release&.external_link.presence || deployment.project_link,
          deep_link: provider&.deep_link(external_release&.external_id, release_platform.platform)
        }
      )
  end

  def production_release_happened?
    production_channel? && (ready_to_release? || rollout_started? || released?)
  end

  private

  def mark_reviewed
    external_release.update(reviewed_at: Time.current)
    event_stamp!(reason: :review_approved, kind: :success, data: stamp_data)
    notify!("Review approved!", :review_approved, notification_params)
  end

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
    notify!("Deployment was successful!", :deployment_finished, notification_params)
  end

  def stamp_data
    {
      version: build_version,
      chan: deployment_channel_name,
      provider: integration&.providable&.display,
      file: build_artifact&.get_filename,
      failure_reason: (display_attr(:failure_reason) if failure_reason.present?)
    }
  end
end
