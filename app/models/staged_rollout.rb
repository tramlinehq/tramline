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
  has_paper_trail
  include AASM
  include Loggable
  include Passportable

  belongs_to :deployment_run

  validates :current_stage, numericality: {greater_than_or_equal_to: 0, allow_nil: true}

  delegate :notify!, :platform, to: :deployment_run

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
    paused: "paused",
    failed: "failed",
    completed: "completed",
    stopped: "stopped",
    fully_released: "fully_released"
  }

  enum status: STATES
  aasm safe_state_machine_params do
    state :created, initial: true, before_enter: -> { deployment_run.rolloutable? }
    state(*STATES.keys)

    event :start, guard: -> { deployment_run.rolloutable? }, after_commit: -> { event_stamp!(reason: :started, kind: :notice, data: stamp_data) } do
      transitions from: :created, to: :started
    end

    event :pause, guard: -> { deployment_run.automatic_rollout? }, after_commit: -> { event_stamp!(reason: :paused, kind: :notice, data: stamp_data) } do
      transitions from: :started, to: :paused
    end

    event :resume, after_commit: -> { event_stamp!(reason: :resumed, kind: :success, data: stamp_data) } do
      transitions from: :paused, to: :started, guard: -> { deployment_run.automatic_rollout? }
      transitions from: :stopped, to: :started, guard: -> { deployment_run.controllable_rollout? }
    end

    event :fail, after_commit: -> { fail_stamp } do
      transitions from: [:started, :failed, :created], to: :failed
    end

    event :retry, guard: -> { deployment_run.rolloutable? } do
      transitions from: :failed, to: :started
    end

    event :halt, guard: -> { deployment_run.rolloutable? }, after_commit: -> { event_stamp!(reason: :halted, kind: :notice, data: stamp_data) } do
      transitions from: [:started, :paused, :failed], to: :stopped
    end

    event :complete, after_commit: -> { event_stamp!(reason: :completed, kind: :success, data: stamp_data) } do
      after { notify!("Staged rollout was completed!", :staged_rollout_completed, notification_params) }
      after { deployment_run.complete! }
      transitions from: [:failed, :started, :paused], to: :completed
    end

    event :full_rollout, after_commit: -> { event_stamp!(reason: :fully_released, kind: :success, data: {rollout_percentage: "%.2f" % config[current_stage]}) } do
      after { deployment_run.complete! }
      transitions from: [:failed, :started], to: :fully_released
    end
  end

  def display_current_stage
    return 0 if created?
    (current_stage || 0).succ
  end

  def update_stage(stage, finish_rollout: false)
    return if stage == current_stage && !finish_rollout

    update!(current_stage: stage)

    if created?
      start!
    else
      event_stamp!(reason: :increased, kind: :notice, data: stamp_data)
    end

    retry! if failed?
    return complete! if finish_rollout && finished?
    notify!("Staged rollout was updated!", :staged_rollout_updated, notification_params)
  end

  def last_rollout_percentage
    return Deployment::FULL_ROLLOUT_VALUE if fully_released?
    return if created? || current_stage.nil?
    return config.last if finished?
    config[current_stage]
  end

  def next_rollout_percentage
    return config.first if created?
    config[current_stage.succ]
  end

  def finished?
    next_rollout_percentage.nil?
  end

  def next_stage
    created? ? 0 : current_stage.succ
  end

  def move_to_next_stage!
    return if completed? || fully_released?

    deployment_run.on_release(rollout_value: next_rollout_percentage) do |result|
      if result.ok?
        update_stage(next_stage, finish_rollout: true)
      else
        fail!
        elog(result.error)
      end
    end
  end

  def halt_release!
    return if created?
    return if completed? || fully_released?

    deployment_run.on_halt_release! do |result|
      if result.ok?
        halt!
        notify!("Release was halted!", :staged_rollout_halted, notification_params)
      else
        elog(result.error)
      end
    end
  end

  def fully_release!
    return if created? || completed? || stopped?

    deployment_run.on_fully_release! do |result|
      if result.ok?
        full_rollout!
        notify!("Staged rollout was accelerated to a full rollout!", :staged_rollout_fully_released, notification_params)
      else
        elog(result.error)
      end
    end
  end

  def pause_release!
    return unless started?

    deployment_run.on_pause_release! do |result|
      if result.ok?
        pause!
        notify!("Staged rollout was paused!", :staged_rollout_paused, notification_params)
      else
        elog(result.error)
      end
    end
  end

  def resume_release!
    return unless (paused? && deployment_run.automatic_rollout?) || (stopped? && deployment_run.controllable_rollout?)

    deployment_run.on_resume_release! do |result|
      if result.ok?
        unless completed?
          resume!
          notify!("Staged rollout was resumed!", :staged_rollout_resumed, notification_params)
        end
      else
        elog(result.error)
      end
    end
  end

  def notification_params
    deployment_run.notification_params.merge(stamp_data)
  end

  private

  def fail_stamp
    if last_rollout_percentage
      event_stamp!(reason: :failed, kind: :error, data: stamp_data)
    else
      event_stamp!(reason: :failed_before_any_rollout, kind: :error, data: stamp_data)
    end
  end

  def stamp_data
    data = {current_stage: display_current_stage, is_fully_released: fully_released?}
    data[:rollout_percentage] = "%.2f" % config[current_stage] if current_stage.present?
    data
  end
end
