# == Schema Information
#
# Table name: deployments
#
#  id                     :uuid             not null, primary key
#  build_artifact_channel :jsonb            indexed => [integration_id, train_step_id]
#  deployment_number      :integer          default(0), not null, indexed => [train_step_id]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  integration_id         :uuid             indexed => [build_artifact_channel, train_step_id], indexed
#  train_step_id          :uuid             not null, indexed => [build_artifact_channel, integration_id], indexed => [deployment_number], indexed
#
class Deployment < ApplicationRecord
  has_paper_trail
  include Displayable

  self.implicit_order_column = :deployment_number

  has_many :deployment_runs, dependent: :destroy
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :deployments
  belongs_to :integration, optional: true

  validates :deployment_number, presence: true
  validates :build_artifact_channel, uniqueness: {scope: [:integration_id, :train_step_id], message: "Deployments should be designed to have unique providers and channels"}

  delegate :google_play_store_integration?, :slack_integration?, :store?, :app_store_integration?, to: :integration, allow_nil: true
  delegate :train, to: :step

  before_save :set_deployment_number, if: :new_record?

  def set_deployment_number
    self.deployment_number = step.deployments.maximum(:deployment_number).to_i + 1
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
    build_artifact_channel["id"]
  end

  def deployment_channel_name
    build_artifact_channel["name"]
  end

  def production_channel?
    store? && build_artifact_channel["is_production"]
  end

  def staged_rollout
    [10, 20, 40, 80, 100]
  end
end
