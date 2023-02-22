# == Schema Information
#
# Table name: deployments
#
#  id                     :uuid             not null, primary key
#  build_artifact_channel :jsonb            indexed => [integration_id, train_step_id]
#  deployment_number      :integer          default(0), not null, indexed => [train_step_id]
#  is_staged_rollout      :boolean          default(FALSE)
#  staged_rollout_config  :decimal(, )      default([]), is an Array
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  integration_id         :uuid             indexed => [build_artifact_channel, train_step_id], indexed
#  train_step_id          :uuid             not null, indexed => [build_artifact_channel, integration_id], indexed => [deployment_number], indexed
#
class Deployment < ApplicationRecord
  has_paper_trail
  include Displayable
  using RefinedString

  self.implicit_order_column = :deployment_number

  has_many :deployment_runs, dependent: :destroy
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :deployments
  belongs_to :integration, optional: true

  validates :deployment_number, presence: true
  validates :build_artifact_channel, uniqueness: {scope: [:integration_id, :train_step_id], message: "Deployments should be designed to have unique providers and channels"}
  validate :staged_rollout_is_allowed
  validate :correct_staged_rollout_config, if: :is_staged_rollout
  validate :non_prod_build_channel, if: -> { step.review? }

  delegate :google_play_store_integration?, :slack_integration?, :store?, :app_store_integration?, to: :integration, allow_nil: true
  delegate :train, to: :step

  scope :sequential, -> { order("deployments.deployment_number ASC") }

  before_save :set_deployment_number, if: :new_record?

  FULL_ROLLOUT_VALUE = BigDecimal("100")

  def staged_rollout? = is_staged_rollout

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

  private

  def staged_rollout_is_allowed
    if is_staged_rollout && !production_channel?
      errors.add(:is_staged_rollout, :prod_only)
    end
  end

  def correct_staged_rollout_config
    if staged_rollout_config.size < 1
      errors.add(:staged_rollout_config, :at_least_one)
    end

    if staged_rollout_config[0]&.zero?
      errors.add(:staged_rollout_config, :zero_rollout)
    end

    if staged_rollout_config.sort != staged_rollout_config
      errors.add(:staged_rollout_config, :increasing_order)
    end
  end

  def non_prod_build_channel
    if production_channel?
      errors.add(:build_artifact_channel, :prod_channel_in_review_not_allowed)
    end
  end
end
