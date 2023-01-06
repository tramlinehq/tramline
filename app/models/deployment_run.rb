# == Schema Information
#
# Table name: deployment_runs
#
#  id                         :uuid             not null, primary key
#  deployment_id              :uuid             not null
#  train_step_run_id          :uuid             not null
#  scheduled_at               :datetime         not null
#  status                     :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  initial_rollout_percentage :decimal(8, 5)
#
class DeploymentRun < ApplicationRecord
  include AASM
  include Passportable

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}
  validates :initial_rollout_percentage, numericality: {greater_than: 0, less_than_or_equal_to: 100, allow_nil: true}

  delegate :step, :release, :commit, to: :step_run
  delegate :deployment_number, to: :deployment

  STAMPABLE_REASONS = ["created", "status_changed", "duplicate_build", "bundle_identifier_not_found"]
  STATES = {
    created: "created",
    started: "started",
    uploaded: "uploaded",
    released: "released",
    failed: "failed"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { step_run.startable_deployment?(deployment) }
    state(*STATES.keys)

    event :dispatch_job do
      transitions from: :created, to: :started
    end

    event :upload do
      transitions from: :started, to: :uploaded
    end

    event :dispatch_fail do
      after { step_run.fail_deploy! }
      transitions from: [:started, :uploaded], to: :failed
    end

    event :complete do
      after { step_run.finish! if deployment.last? }
      transitions from: [:created, :uploaded, :started], to: :released
    end
  end

  after_commit -> {
    create_stamp!(data: {num: deployment_number, step_name: step.name, sha_link: commit.url, sha: commit.short_sha})
  }, on: :create
  after_commit -> {
    status_update_stamp!(data: {num: deployment_number, step_name: step.name, sha_link: commit.url, sha: commit.short_sha})
  }, if: -> { saved_change_to_attribute?(:status) }, on: :update

  def promote!
    save!
    return unless promotable?
    return unless deployment.integration.google_play_store_integration?

    release.with_lock do
      package_name = step.app.bundle_identifier
      release_version = step_run.train_run.release_version
      api = Installations::Google::PlayDeveloper::Api.new(package_name, deployment.access_key, release_version)
      api.promote(deployment.deployment_channel, step_run.build_number, initial_rollout_percentage)

      complete!
    rescue Installations::Errors::BuildNotUpgradable => e
      logger.error(e)
      Sentry.capture_exception(e)
      dispatch_fail!
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

  def previous_rollout
    initial_run.initial_rollout_percentage
  end

  def previously_rolled_out?
    rolloutable? && noninitial?
  end
end
