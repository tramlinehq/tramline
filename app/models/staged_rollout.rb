# == Schema Information
#
# Table name: staged_rollouts
#
#  id                :uuid             not null, primary key
#  config            :decimal(, )      default([]), is an Array
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
  delegate :promote_with, to: :deployment_run

  STATES = {
    started: "started",
    paused: "paused",
    completed: "completed",
    stopped: "stopped"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :started, initial: true
    state(*STATES.keys)

    event :pause do
      transitions from: :started, to: :paused
    end

    event :resume do
      transitions from: :paused, to: :started
    end

    event :halt do
      after { deployment_run.complete! }
      transitions from: [:started, :paused], to: :stopped
    end

    event :complete do
      after { deployment_run.complete! }
      transitions from: :started, to: :completed
    end
  end

  def last_rollout_percentage
    config[current_stage]
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

  def move_to_next_stage!
    return complete! if finished?

    promote_with(next_rollout_percentage) do |_ok_result|
      update!(current_stage: next_stage)
    end
  end
end
