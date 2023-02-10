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
  include AASM
  include Passportable
  include Loggable

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  has_one :external_build, dependent: :destroy

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}
  validates :initial_rollout_percentage, numericality: {greater_than: 0, less_than_or_equal_to: 100, allow_nil: true}

  delegate :step, :release, :commit, :build_number, :build_artifact, :build_version, to: :step_run
  delegate :app, to: :step
  delegate :ios?, to: :app
  delegate :release_version, to: :release
  delegate :external?, :google_play_store_integration?, :slack_integration?, :store?, :app_store_integration?, to: :deployment
  delegate :deployment_number, :integration, :deployment_channel, :deployment_channel_name, to: :deployment

  scope :for_ids, ->(ids) { includes(deployment: :integration).where(id: ids) }

  STAMPABLE_REASONS = [
    "created",
    "bundle_identifier_not_found",
    "invalid_package",
    "apks_are_not_allowed",
    "upload_failed_reason_unknown",
    "promotion_failed",
    "released"
  ]

  STATES = {
    created: "created",
    started: "started",
    submitted: "submitted",
    uploaded: "uploaded",
    upload_failed: "upload_failed",
    released: "released",
    failed: "failed"
  }

  enum status: STATES

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

    event :upload do
      after { wrap_up_uploads! }
      transitions from: :started, to: :uploaded
    end

    event :upload_fail do
      after { step_run.fail_deploy! }
      transitions from: :started, to: :upload_failed
    end

    event :dispatch_fail do
      after { step_run.fail_deploy! }
      transitions from: [:uploaded, :submitted], to: :failed
    end

    event :complete do
      after { step_run.finish! if step_run.finished_deployments? }
      transitions from: [:created, :uploaded, :started, :submitted], to: :released
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

  def promote!
    save!
    return unless google_play_store_integration?

    release.with_lock do
      return unless promotable?

      result = provider.promote(deployment_channel, build_number, release_version, initial_rollout_percentage)
      if result.ok?
        complete!
        event_stamp!(reason: :released, kind: :success, data: stamp_data)
      else
        dispatch_fail!
        event_stamp!(reason: :promotion_failed, kind: :error, data: stamp_data)
        elog(result.error)
      end
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

  def promote_to_appstore!
    return unless app_store_integration?
    provider.promote_to_testflight(deployment_channel, build_number)
    submit!
  end

  def push_to_slack!
    return unless slack_integration?

    with_lock do
      return if released?
      provider.deploy!(deployment_channel, {step_run: step_run})
      complete!
      event_stamp!(reason: :released, kind: :success, data: stamp_data)
    end
  end

  # FIXME: this is cheap hack around not allowing users to re-enter rollout
  # since that can cause users to downgrade subsequent build rollouts
  # we want users to only upgrade or keep the same initial rollout they entered the first time
  # even after subsequent deployment runs / commits land
  def noninitial?
    initial_run.present?
  end

  def promotable?
    release.on_track? && uploaded? && deployment.google_play_store_integration?
  end

  def rolloutable?
    promotable? && deployment.last? && step.last?
  end

  def initial_run
    deployment
      .deployment_runs
      .includes(step_run: :train_run)
      .where(step_run: {train_runs: release})
      .where.not(id:)
      .first
  end

  def has_uploaded?
    uploaded? || failed? || released?
  end

  # FIXME: should we take a lock around this SR? what is someone double triggers the run?
  def start_upload!
    # TODO: simplify this logic
    if store?
      other_deployment_runs = step_run.similar_deployment_runs_for(self)
      return upload! if other_deployment_runs.any?(&:has_uploaded?)
      return if other_deployment_runs.any?(&:started?)
    end

    return Deployments::GooglePlayStore::Upload.perform_later(id) if google_play_store_integration?
    Deployments::Slack.perform_later(id) if slack_integration?
  end

  def start_distribution!
    return unless store? && app_store_integration?
    Deployments::AppStoreConnect::TestFlightPromoteJob.perform_later(id)
  end

  def wrap_up_uploads!
    return unless store?
    step_run
      .similar_deployment_runs_for(self)
      .select(&:started?)
      .each { |run| run.upload! }
  end

  def previous_rollout
    initial_run.initial_rollout_percentage
  end

  def previously_rolled_out?
    rolloutable? && noninitial?
  end

  def provider
    integration.providable
  end

  private

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
