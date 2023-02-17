# == Schema Information
#
# Table name: staged_rollouts
#
#  id                :uuid             not null, primary key
#  config            :decimal(8, 5)    default([]), is an Array
#  current_stage     :integer
#  status            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  deployment_run_id :uuid             not null, indexed
#
class StagedRollout < ApplicationRecord
  include AASM
  include Loggable

  belongs_to :deployment_run
  delegate :release_with, :halt_release_in_playstore!, to: :deployment_run

  validates :current_stage, numericality: {greater_than_or_equal_to: 0, allow_nil: true}

  STATES = {
    started: "started",
    failed: "failed",
    completed: "completed",
    stopped: "stopped"
  }

  enum status: STATES
  aasm safe_state_machine_params do
    state :started, initial: true
    state(*STATES.keys)

    event :fail do
      transitions from: [:started, :failed], to: :failed
    end

    event :retry do
      transitions from: :failed, to: :started
    end

    event :halt do
      after { deployment_run.complete! }
      transitions from: [:started, :paused], to: :stopped
    end

    event :complete do
      after { deployment_run.complete! }
      transitions from: [:failed, :started], to: :completed
    end
  end

  def last_rollout_percentage
    config[current_stage] unless current_stage.nil?
  end

  def next_rollout_percentage
    return config.first if current_stage.nil?
    config[current_stage.succ]
  end

  def finished?
    next_rollout_percentage.nil?
  end

  def next_stage
    current_stage.nil? ? 0 : current_stage.succ
  end

  def reached?(stage)
    current_stage && current_stage >= stage
  end

  def roll_out_started?
    current_stage && started?
  end

  def move_to_next_stage!
    return if completed?

    release_with(rollout_value: next_rollout_percentage) do |result|
      if result.ok?
        update!(current_stage: next_stage)
        retry! if failed?
        complete! if finished?
      else
        fail!
        elog(result.error)
      end
    end
  end

  def halt_release!
    return if last_rollout_percentage.nil?

    halt_release_in_playstore!(rollout_value: last_rollout_percentage) do |result|
      if result.ok?
        halt!
      else
        elog(result.error)
      end
    end
  end
end
