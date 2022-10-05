class Deployment < ApplicationRecord
  has_paper_trail

  self.implicit_order_column = :deployment_number

  has_many :deployment_runs
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :deployments
  belongs_to :integration, optional: true

  validates :deployment_number, presence: true
  validates :build_artifact_channel, uniqueness: {scope: [:integration_id, :train_step_id], message: "Deployments should be designed to have unique providers and channels"}

  delegate :google_play_store_integration?, to: :integration, allow_nil: true
  delegate :slack_integration?, to: :integration, allow_nil: true
  delegate :train, to: :step

  before_save :set_deployment_number, if: :new_record?

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

  def deployment_channel
    build_artifact_channel.values.first
  end

  def available_deployment_channels
    if external?
      [["External", {"external" => "external"}.to_json]]
    else
      deployment.integration.providable.channels
    end
  end
end
