class DeploymentRun < ApplicationRecord
  include AASM

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  validates :deployment_id, uniqueness: {scope: :train_step_run_id}
  validates :initial_rollout_percentage, numericality: {greater_than: 0, less_than_or_equal_to: 100, allow_nil: true}

  delegate :step, to: :step_run

  unless const_defined?(:STATES)
    STATES = {
      created: "created",
      started: "started",
      uploaded: "uploaded",
      released: "released",
      failed: "failed"
    }
  end

  enum status: STATES

  aasm column: :status, requires_lock: true, requires_new_transaction: false, enum: true, create_scopes: false do
    state :created, initial: true, before_enter: -> { deployment.startable? }
    state(*STATES.keys)

    event :dispatch_job do
      transitions from: :created, to: :started
    end

    event :upload do
      transitions from: :started, to: :uploaded
    end

    event :dispatch_fail do
      transitions from: [:started, :uploaded], to: :failed
    end

    event :release do
      after { step_run.finish! if deployment.last? } # FIXME: is this correct?
      transitions from: [:created, :uploaded, :started], to: :released
    end
  end

  def promote!(rollout_percentage)
    with_lock do
      return unless promotable?
      self.initial_rollout_percentage = rollout_percentage
      save!
      Deployments::GooglePlayStore::Promote.perform_later(id)
    end
  end

  def promotable?
    uploaded? && deployment.google_play_store_integration?
  end

  def rolloutable?
    promotable? && deployment.last? && step.last?
  end
end
