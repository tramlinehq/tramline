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

  delegate :step, :release, :commit, to: :step_run
  delegate :deployment_number, :integration, :external?, :google_play_store_integration?, :slack_integration?, to: :deployment

  STAMPABLE_REASONS = ["created", "status_changed", "duplicate_build", "bundle_identifier_not_found"]
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
      transitions from: :created, to: :started
    end

    event :upload do
      transitions from: [:created, :started], to: :uploaded
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
      after { step_run.finish! if deployment.last? }
      transitions from: [:created, :uploaded, :started], to: :released
    end
  end

  scope :matching_runs_for, ->(integration) { includes(:deployment).where(deployments: {integration: integration}) }
  scope :has_begun, -> { where.not(status: :created) }

  after_commit -> {
    create_stamp!(data: {num: deployment_number, step_name: step.name, sha_link: commit.url, sha: commit.short_sha})
  }, on: :create
  after_commit -> {
    status_update_stamp!(data: {num: deployment_number, step_name: step.name, sha_link: commit.url, sha: commit.short_sha})
  }, if: -> { saved_change_to_attribute?(:status) }, on: :update

  def promote!
    save!
    return unless deployment.integration.google_play_store_integration?

    release.with_lock do
      return unless promotable?
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

  def has_uploaded?
    uploaded? || failed? || released?
  end

  # FIXME: should we take a lock around this SR? what is someone double triggers the run?
  def start_upload!
    return complete! if external?

    other_deployment_runs = step_run.similar_deployment_runs_for(self)
    return upload! if other_deployment_runs.any?(&:has_uploaded?)
    return if other_deployment_runs.any?(&:started?)

    return Deployments::GooglePlayStore::Upload.perform_later(id) if google_play_store_integration?
    Deployments::Slack.perform_later(id) if slack_integration?
  end

  # def already_uploaded?
  #   step_run
  #     .similar_deployment_runs_for(self)
  #     .then
  #     .detect { |runs| runs.any?(&:has_uploaded?) }
  #     .then(&:upload!)
  # end

  def previous_rollout
    initial_run.initial_rollout_percentage
  end

  def previously_rolled_out?
    rolloutable? && noninitial?
  end
end
