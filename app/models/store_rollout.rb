# == Schema Information
#
# Table name: store_rollouts
#
#  id                      :bigint           not null, primary key
#  completed_at            :datetime
#  config                  :decimal(8, 5)    default([]), not null, is an Array
#  current_stage           :integer
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#  store_submission_id     :uuid             indexed
#
class StoreRollout < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :store_submission
  belongs_to :release_platform_run

  STAMPABLE_REASONS = %w[
    started
    paused
    resumed
    increased
    completed
    halted
    fully_released
  ]
  STATES = {
    created: "created",
    started: "started",
    completed: "completed",
    halted: "halted",
    fully_released: "fully_released"
  }

  enum status: STATES

  delegate :update_store_info!, :build, :deployment_channel, to: :store_submission
  delegate :production_release, :pre_prod_release, to: :store_submission, allow_nil: true
  delegate :version_name, :build_number, to: :build
  delegate :train, to: :release_platform_run
  delegate :notify!, to: :train

  protected

  def staged_rollout? = true # FIXME - get this configuration from train settings

  def provider = release_platform_run.store_provider

  def finished? = completed? || fully_released?

  def reached_last_stage? = next_rollout_percentage.nil?

  def stage
    return 0 if created?
    (current_stage || 0).succ
  end

  def next_rollout_percentage
    return config.first if created?
    config[current_stage.succ]
  end

  def last_rollout_percentage
    return Release::FULL_ROLLOUT_VALUE if fully_released?
    return if created? || current_stage.nil?
    return config.last if reached_last_stage?
    config[current_stage]
  end

  def next_stage
    created? ? 0 : current_stage.succ
  end

  def update_stage(stage, finish_rollout: false)
    return if stage == current_stage && !finish_rollout

    update!(current_stage: stage)

    if may_start?
      start!
    else
      event_stamp!(reason: :increased, kind: :notice, data: stamp_data)
    end

    complete! if finish_rollout && reached_last_stage?
  end

  def notification_params
    store_submission.notification_params.merge(stamp_data)
  end

  def stamp_data
    data = {
      current_stage: stage,
      is_fully_released: fully_released?
    }

    if current_stage.present?
      data[:rollout_percentage] = "%.2f" % config[current_stage]
    end

    data
  end

  def on_complete!
    production_release.rollout_complete!
  end

  def set_completed_at!
    update! completed_at: Time.current
  end
end

# TODO:
# - handle managed publishing
# - handle previous staged rollout value in the next rollout
# - handle rollouts for non-prod
# - external release in play store?
