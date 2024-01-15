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
  using RefinedString

  belongs_to :step_run, inverse_of: :deployment_runs
  belongs_to :deployment, inverse_of: :deployment_runs
  has_one :staged_rollout, dependent: :destroy
  has_one :external_release, dependent: :destroy
  has_many :release_health_metrics, dependent: :destroy, inverse_of: :deployment_run
  has_many :release_health_events, dependent: :destroy, inverse_of: :deployment_run

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
  delegate :train, :app, to: :release
  delegate :release_version, :release_metadata, :platform, to: :release_platform_run
  delegate :release_health_rules, to: :release_platform

  STAMPABLE_REASONS = %w[
    created
    release_failed
    prepare_release_failed
    inflight_release_replaced
    submitted_for_review
    review_approved
    release_started
    released
    review_failed
    skipped
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
    review_failed: "review_failed",
    failed_with_action_required: "failed_with_action_required",
    failed: "failed"
  }

  READY_STATES = [STATES[:rollout_started], STATES[:ready_to_release], STATES[:released]]
  STORE_SUBMISSION_STATES = READY_STATES + [STATES[:submitted_for_review], STATES[:review_failed]]

  enum status: STATES
  enum failure_reason: {
    developer_rejected: "developer_rejected",
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
      transitions from: [:submitted_for_review, :review_failed], to: :ready_to_release
    end

    event :engage_release, after_commit: :on_release_started do
      transitions from: [:uploaded, :ready_to_release], to: :rollout_started
    end

    event :fail_review, after_commit: :after_review_failure do
      transitions from: :submitted_for_review, to: :review_failed
    end

    event :fail_with_sync_option, before: :set_reason do
      transitions from: [:started, :prepared_release, :uploading, :uploaded, :submitted_for_review, :ready_to_release, :rollout_started, :failed_prepare_release, :failed_with_action_required], to: :failed_with_action_required
      after { step_run.fail_deployment_with_sync_option! }
    end

    event :skip, after_commit: -> { event_stamp!(reason: :skipped, kind: :notice, data: stamp_data) } do
      transitions from: :failed_with_action_required, to: :released
      after { step_run.finish_deployment!(deployment) }
    end

    event :dispatch_fail, before: :set_reason, after_commit: :release_failed do
      transitions from: [:started, :prepared_release, :uploading, :uploaded, :submitted_for_review, :ready_to_release, :rollout_started, :failed_prepare_release], to: :failed
      after { step_run.fail_deployment!(deployment) }
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

  def self.reached_production
    ready.includes(:step_run, :deployment).select(&:production_channel?)
  end

  def healthy?
    return true if release_health_rules.blank?
    return true if release_health_events.blank?

    rule_health = release_health_rules.map do |rule|
      release_health_events.where(release_health_rule: rule).last&.healthy?
    end.compact

    rule_health.all?
  end

  def fetch_health_data!
    return if app.monitoring_provider.blank?
    return unless production_channel?

    release_data = app.monitoring_provider.find_release(platform, build_version, build_number)
    return if release_data.blank?

    release_health_metrics.create(fetched_at: Time.current, **release_data)
  end

  def latest_health_data
    release_health_metrics.order(fetched_at: :desc).first
  end

  def staged_rollout_events
    return [] unless staged_rollout?

    staged_rollout.passports.where(reason: [:started, :increased, :fully_released]).order(:event_timestamp).map do |p|
      {
        timestamp: p.event_timestamp,
        rollout_percentage: (p.reason == "fully_released") ? "100%" : p.metadata["rollout_percentage"]
      }
    end
  end

  def rollout_percentage_at(day)
    return 100.0 unless staged_rollout
    last_event = staged_rollout
      .passports
      .where(reason: [:started, :increased, :fully_released])
      .where("DATE_TRUNC('day', event_timestamp) <= ?", day)
      .order(:event_timestamp)
      .last
    return 0.0 unless last_event
    return 100.0 if last_event.reason == "fully_released"
    last_event.metadata["rollout_percentage"].safe_float
  end

  def submitted_at
    return unless released?
    return unless production_channel?

    if google_play_store_integration?
      release_started_at
    elsif app_store_integration?
      passports.where(reason: :submitted_for_review).last&.event_timestamp
    end
  end

  def release_started_at
    return unless released?
    return unless production_channel?

    passport = passports.where(reason: :release_started).last

    return passport.event_timestamp if passport

    # NOTE: closest timestamp for releases finished before the above passport was added
    return staged_rollout.created_at if staged_rollout
    passports.where(reason: :released).last.event_timestamp
  end

  def first?
    step_run.deployment_runs.first == self
  end

  def after_submission
    notify!("Submitted for review!", :submit_for_review, notification_params)
    event_stamp!(reason: :submitted_for_review, kind: :notice, data: stamp_data)
    Deployments::AppStoreConnect::UpdateExternalReleaseJob.perform_async(id)
  end

  def after_review_failure
    notify!("Review failed", :review_failed, notification_params)
    event_stamp!(reason: :review_failed, kind: :error, data: stamp_data)
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
      if error.reason == :app_review_rejected
        fail_with_sync_option!(reason: error.reason)
      else
        dispatch_fail!(reason: error.reason)
      end
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
    production_channel? && status.in?(READY_STATES)
  end

  def production_release_submitted?
    production_channel? && status.in?(STORE_SUBMISSION_STATES)
  end

  private

  def on_release_started
    event_stamp!(reason: :release_started, kind: :notice, data: stamp_data)
    ReleasePlatformRuns::CreateTagJob.perform_later(release_platform_run.id) if production_channel? && train.tag_all_store_releases?
    Releases::FetchHealthMetricsJob.perform_later(id) if app.monitoring_provider.present?
  end

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
    notify!("Deployment failed", :deployment_failed, notification_params)
  end

  def release_success
    if external_release
      now = Time.current
      external_release.update(released_at: now, reviewed_at: external_release.reviewed_at.presence || now)
    end

    event_stamp!(reason: :released, kind: :success, data: stamp_data)
    train.notify_with_snippet!("Deployment was successful!", :deployment_finished, notification_params, step_run.build_notes, "Changes since the last release:")
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
