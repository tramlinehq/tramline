# == Schema Information
#
# Table name: deployments
#
#  id                     :uuid             not null, primary key
#  build_artifact_channel :jsonb            indexed => [integration_id, step_id]
#  deployment_number      :integer          default(0), not null, indexed => [step_id]
#  discarded_at           :datetime         indexed
#  is_staged_rollout      :boolean          default(FALSE)
#  send_build_notes       :boolean
#  send_release_notes     :boolean          default(FALSE)
#  staged_rollout_config  :decimal(, )      default([]), is an Array
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  integration_id         :uuid             indexed => [build_artifact_channel, step_id], indexed
#  step_id                :uuid             not null, indexed => [build_artifact_channel, integration_id], indexed => [deployment_number], indexed
#
class Deployment < ApplicationRecord
  has_paper_trail
  include Displayable
  include Discard::Model

  self.implicit_order_column = :deployment_number

  has_many :deployment_runs, dependent: :destroy
  belongs_to :step, inverse_of: :deployments
  belongs_to :integration, optional: true

  attr_accessor :send_notes

  validates :deployment_number, presence: true
  validates :build_artifact_channel, uniqueness: {scope: [:integration_id, :step_id]}
  validate :staged_rollout_is_allowed
  validate :correct_staged_rollout_config, if: :staged_rollout?, on: :create
  validate :non_prod_build_channel, if: -> { step.review? }

  delegate :google_play_store_integration?,
    :slack_integration?,
    :store?,
    :app_store_integration?,
    :controllable_rollout?,
    :google_firebase_integration?, :project_link, to: :integration, allow_nil: true
  delegate :train, :app, :notify!, :release_platform, to: :step

  scope :sequential, -> { order("deployments.deployment_number ASC") }

  after_initialize :set_notes_config
  before_save :set_deployment_number, if: :new_record?
  before_save :set_default_staged_rollout, if: [:new_record?, :app_store_integration?, :staged_rollout?]
  before_save :set_default_prod_notes_config, if: [:new_record?, :production_channel?]

  FULL_ROLLOUT_VALUE = BigDecimal("100")

  def staged_rollout? = is_staged_rollout

  def send_notes?
    send_build_notes? || send_release_notes?
  end

  def set_deployment_number
    self.deployment_number = step.all_deployments.maximum(:deployment_number).to_i + 1
  end

  def external?
    integration.nil?
  end

  def uploadable?
    slack_integration? || google_firebase_integration? || google_play_store_integration? || (release_platform.android? && external?)
  end

  def findable?
    release_platform.ios? && app_store_integration?
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

  def internal_channel?
    build_artifact_channel["is_internal"]
  end

  def requires_review?
    google_play_store_integration? && deployment_channel.in?(%w[production beta alpha])
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
          is_staged_rollout_deployment: staged_rollout?,
          is_production_channel: production_channel?,
          is_play_store_production: production_channel? && google_play_store_integration?,
          is_app_store_production: app_store?,
          deployment_channel_type: integration_type&.to_s&.titleize,
          deployment_channel: build_artifact_channel,
          deployment_channel_asset_link: integration&.public_icon_img,
          requires_review: requires_review?
        }
      )
  end

  def replicate(new_step)
    new_deployment = dup
    new_step.deployments << new_deployment
  end

  private

  def set_notes_config
    return self.send_notes = "send_build_notes" if send_build_notes?
    return self.send_notes = "send_release_notes" if send_release_notes?
    self.send_notes = "send_no_notes"
  end

  def set_default_prod_notes_config
    self.send_release_notes = true
  end

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
