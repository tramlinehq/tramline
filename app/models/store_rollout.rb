# == Schema Information
#
# Table name: store_rollouts
#
#  id                      :bigint           not null, primary key
#  config                  :decimal(8, 5)    default([]), not null, is an Array
#  current_stage           :integer
#  release_channel         :jsonb            not null
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class StoreRollout < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :release_platform_run
  belongs_to :build

  STAMPABLE_REASONS = %w[
    started
    paused
    failed
    resumed
    increased
    completed
    halted
    fully_released
  ]

  STATES = {
    created: "created",
    started: "started",
    failed: "failed",
    completed: "completed",
    halted: "halted",
    fully_released: "fully_released"
  }

  enum status: STATES

  delegate :version_name, :build_number, to: :build
  delegate :train, to: :release_platform_run
  delegate :notify!, to: :train

  protected

  def provider
    release_platform_run.store_provider
  end

  def finished?
    next_rollout_percentage.nil?
  end

  def next_rollout_percentage
    return config.first if created?
    config[current_stage.succ]
  end

  def last_rollout_percentage
    return Deployment::FULL_ROLLOUT_VALUE if fully_released?
    return if created? || current_stage.nil?
    return config.last if finished?
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
      event_stamp!(reason: :increased, kind: :notice, data: {})
    end

    return complete! if finish_rollout && finished?
    notify!("Staged rollout was updated!", :staged_rollout_updated, notification_params)
  end

  def notification_params
    {}
  end
end

# TODO:
# - handle managed publishing
# - handle previous staged rollout value in the next rollout
# - handle rollouts for non-prod
# - external release in play store?
# - check for rolloutable?
