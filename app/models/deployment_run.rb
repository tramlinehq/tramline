class DeploymentRun < ApplicationRecord
  include AASM

  belongs_to :deployment, inverse_of: :deployment_runs
  belongs_to :step_run, class_name: "Releases::Step::Run", foreign_key: :train_step_run_id, inverse_of: :deployment_runs

  validates :initial_rollout_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100, allow_nil: true }

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
    state :created, initial: true
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
      after { step_run.finish! if deployment.last? }
      transitions from: [:created, :uploaded, :started], to: :released
    end
  end

  def promote!
    return unless promotable?
    Deployments::GooglePlayStore::Promote.perform_later(id, initial_rollout_percentage)
  end

  def promotable?
    uploaded? && deployment.google_play_store_integration?
  end

  def rolloutable?
    promotable? && deployment.last? && step.last?
  end
end
