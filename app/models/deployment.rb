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

  self.implicit_order_column = :deployment_number

  has_many :deployment_runs, dependent: :destroy
  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id, inverse_of: :deployments
  belongs_to :integration, optional: true

  validates :deployment_number, presence: true
  validates :build_artifact_channel, uniqueness: {scope: [:integration_id, :train_step_id], message: "Deployments should be designed to have unique providers and channels"}
  validate :staged_rollout_is_allowed
  validate :correct_staged_rollout_config, if: :staged_rollout?
  validate :non_prod_build_channel, if: -> { step.review? }

  delegate :google_play_store_integration?,
    :slack_integration?,
    :store?,
    :app_store_integration?,
    :controllable_rollout?,
    :google_firebase_integration?, to: :integration, allow_nil: true
  delegate :train, :app, to: :step

  scope :sequential, -> { order("deployments.deployment_number ASC") }

  before_save :set_deployment_number, if: :new_record?
  before_save :set_default_staged_rollout, if: [:new_record?, :app_store_integration?, :staged_rollout?]

  FULL_ROLLOUT_VALUE = BigDecimal("100")

  def staged_rollout? = is_staged_rollout

  def set_deployment_number
    self.deployment_number = step.deployments.maximum(:deployment_number).to_i + 1
  end

  def external?
    integration.nil?
  end

  def uploadable?
    slack_integration? || google_firebase_integration? || google_play_store_integration? || (app.android? && external?)
  end

  def findable?
    app.ios? && (app_store_integration? || external?)
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

  def integration_type
    return :app_store if app_store?
    return :testflight if test_flight?
    return :google_play_store if google_play_store_integration?
    return :slack if slack_integration?
    return :firebase if google_firebase_integration?
    :external
  end

  def display_channel?
    !external? && !app_store?
  end

  def test_flight?
    !production_channel? && app_store_integration?
  end

  def app_store?
    production_channel? && app_store_integration?
  end

  def notification_params
    step.notification_params
      .merge(train.notification_params)
      .merge(
        {
          staged_rollout_deployment: staged_rollout?,
          production_channel?: production_channel?,
          deployment_channel_type: integration_type,
          deployment_channel_name: deployment_channel_name
        }
      )
  end

  private

  def set_default_staged_rollout
    self.staged_rollout_config = AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE
  end

  def staged_rollout_is_allowed
    if is_staged_rollout && !production_channel?
      errors.add(:is_staged_rollout, :prod_only)
    end
  end

  def correct_staged_rollout_config
    if app_store_integration?
      errors.add(:staged_rollout_config, :not_allowed) if staged_rollout_config.present?
      return
    end

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
