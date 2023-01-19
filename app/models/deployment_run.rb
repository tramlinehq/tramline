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

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}
  validates :initial_rollout_percentage, numericality: {greater_than: 0, less_than_or_equal_to: 100, allow_nil: true}

  delegate :step, :release, :commit, :build_number, :build_artifact, :build_version, to: :step_run
  delegate :app, to: :step
  delegate :release_version, to: :release
  delegate :external?, :google_play_store_integration?, :slack_integration?, :store?, to: :deployment
  delegate :deployment_number, :integration, :deployment_channel, :deployment_channel_name, to: :deployment

  STAMPABLE_REASONS = [
    "created",
    "bundle_identifier_not_found",
    "invalid_package",
    "apks_are_not_allowed",
    "promotion_failed",
    "released"
  ]

  STATES = {
    created: "created",
    started: "started",
    uploaded: "uploaded",
    upload_failed: "upload_failed",
    released: "released",
    failed: "failed"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { step_run.startable_deployment?(deployment) }
    state(*STATES.keys)

    event :dispatch_job, after_commit: :start_upload! do
      after { step_run.ready_to_deploy! if first? }
      transitions from: :created, to: :started
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
      transitions from: :uploaded, to: :failed
    end

    event :complete do
      after { step_run.finish! if step_run.finished_deployments? }
      transitions from: [:created, :uploaded, :started], to: :released
    end
  end

  scope :matching_runs_for, ->(integration) { includes(:deployment).where(deployments: {integration: integration}) }
  scope :has_begun, -> { where.not(status: :created) }

  after_commit -> { create_stamp!(data: stamp_data) }, on: :create

  def first?
    step_run.deployment_runs.first == self
  end

  def promote!
    save!
    return unless google_play_store_integration?

    release.with_lock do
      return unless promotable?

      if provider.promote(deployment_channel, build_number, release_version, initial_rollout_percentage).ok?
        complete!
        event_stamp!(reason: :released, kind: :success, data: stamp_data)
      else
        dispatch_fail!
        event_stamp!(reason: :promotion_failed, kind: :error, data: stamp_data)
      end
    end
  end

  def upload_to_playstore!
    return unless google_play_store_integration?

    build_artifact.with_open do |file|
      result = provider.upload(file)

      if result.ok?
        upload!
      else
        reason = GooglePlayStoreIntegration::DISALLOWED_ERRORS_WITH_REASONS[result.error.class]
        event_stamp!(reason:, kind: :error, data: stamp_data) if reason.present?
        upload_fail!
      end
    end
  end

  def push_to_slack!
    return unless slack_integration?

    provider.deploy!(deployment_channel, {step_run: step_run})
    complete!
    event_stamp!(reason: :released, kind: :success, data: stamp_data)
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
    return complete! if external?

    # TODO: simplify this logic
    if store?
      other_deployment_runs = step_run.similar_deployment_runs_for(self)
      return upload! if other_deployment_runs.any?(&:has_uploaded?)
      return if other_deployment_runs.any?(&:started?)
    end

    return Deployments::GooglePlayStore::Upload.perform_later(id) if google_play_store_integration?
    Deployments::Slack.perform_later(id) if slack_integration?
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
end
