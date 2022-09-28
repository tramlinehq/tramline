class Deployment < ApplicationRecord
  has_paper_trail

  has_many :deployment_runs
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :deployments
  belongs_to :integration, optional: true

  before_validation :set_deployment_number, if: :new_record?

  delegate :google_play_store_integration?, to: :integration, allow_nil: true
  delegate :slack_integration?, to: :integration, allow_nil: true
  delegate :train, to: :step

  def set_deployment_number
    self.deployment_number = step.deployments.maximum(:deployment_number).to_i + 1
  end

  def access_key
    StringIO.new(integration.providable.json_key) if requires_access_key?
  end

  def requires_access_key?
    google_play_store_integration?
  end

  def external?
    integration.nil?
  end

  def startable?
    return false if train.inactive?
    return false if train.active_run.nil?
    return true if deployment_runs.empty? && first?
    return false if first?

    next_active == self && last_deployment_run.released?
  end

  def active_step_run
    train.active_run&.active_step_run
  end

  def last_deployment_run
    active_step_run&.last_deployment_run
  end

  def next_active
    active_step_run&.next_deployment
  end

  def first?
    step.deployments.minimum(:deployment_number).to_i == deployment_number
  end

  def last?
    step.deployments.maximum(:deployment_number).to_i == deployment_number
  end

  def next
    step.deployments.where("deployment_number > ?", deployment_number)&.first
  end

  def previous
    step.deployments.where("deployment_number < ?", deployment_number).last
  end
end

