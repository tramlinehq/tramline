# == Schema Information
#
# Table name: store_rollouts
#
#  id                               :uuid             not null, primary key
#  automatic_rollout                :boolean          default(FALSE), not null, indexed
#  automatic_rollout_next_update_at :datetime
#  automatic_rollout_updated_at     :datetime
#  completed_at                     :datetime
#  config                           :decimal(8, 5)    default([]), not null, is an Array
#  current_stage                    :integer
#  is_staged_rollout                :boolean          default(FALSE), indexed
#  status                           :string           not null, indexed
#  type                             :string           not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  release_platform_run_id          :uuid             not null, indexed
#  store_submission_id              :uuid             indexed
#
class PlayStoreRollout < StoreRollout
  include Passportable

  belongs_to :play_store_submission, foreign_key: :store_submission_id, inverse_of: :play_store_rollout
  delegate :submission_channel_id, :submission_channel, :update_external_status, to: :store_submission

  STAMPABLE_REASONS = %w[
    started
    updated
    paused
    resumed
    halted
    completed
    failed
    fully_released
  ]

  AUTO_ROLLOUT_RUN_INTERVAL = 24.hours

  aasm safe_state_machine_params(with_lock: false) do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
      transitions from: :created, to: :started
    end

    event :pause, after_commit: :on_pause! do
      transitions from: :started, to: :paused
    end

    event :resume, after_commit: :on_resume! do
      transitions from: :paused, to: :started
      transitions from: :halted, to: :started
    end

    event :halt, after_commit: :on_halt! do
      transitions from: [:started, :paused], to: :halted
    end

    event :complete, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: [:started, :created], to: :completed
    end

    event :fully_release, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: [:completed, :started], to: :fully_released
    end
  end

  def controllable_rollout? = true

  def start_release!(retry_on_review_fail: false, rollout_percentage: nil)
    if staged_rollout?
      # return mock_start_play_store_rollout! if sandbox_mode?
      start_with_percentage!(rollout_percentage, retry_on_review_fail:)
    else
      # return mock_complete_play_store_rollout! if sandbox_mode?
      result = rollout(Release::FULL_ROLLOUT_VALUE, retry_on_review_fail:)
      if result.ok?
        complete!
        event_stamp!(reason: :completed, kind: :success, data: stamp_data)
      else
        fail!(result.error)
      end
    end
  end

  def start_with_percentage!(percentage, retry_on_review_fail: true)
    with_lock do
      return if completed? || fully_released?

      target_percentage = percentage.presence || next_rollout_percentage
      result = rollout(target_percentage, retry_on_review_fail:)
      if result.ok?
        target_stage = find_stage_for_percentage(target_percentage)
        update_stage(target_stage, finish_rollout: reached_stage?(target_stage))
      else
        if result.error.is_a?(Installations::Error) && result.error.reason == :fully_released_can_not_be_staged
          fully_release!
          return
        end
        fail!(result.error)
      end
    end
  end

  def move_to_next_stage!(retry_on_review_fail: true)
    with_lock do
      return if completed? || fully_released?

      result = rollout(next_rollout_percentage, retry_on_review_fail:)
      if result.ok?
        update_stage(next_stage, finish_rollout: true)
      else
        if result.error.is_a?(Installations::Error) && result.error.reason == :fully_released_can_not_be_staged
          fully_release!
          return
        end
        fail!(result.error)
      end
    end
  end

  def release_fully!
    # return fully_release! if sandbox_mode?
    with_lock do
      return unless may_fully_release?

      rollout_value = Release::FULL_ROLLOUT_VALUE
      result = rollout(rollout_value, retry_on_review_fail: true)
      if result.ok?
        fully_release!
        event_stamp!(reason: :fully_released, kind: :success, data: stamp_data)
      else
        fail!(result.error)
      end
    end
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_release(
        submission_channel_id,
        build_number,
        release_version,
        last_rollout_percentage,
        retry_on_review_fail: true,
        raise_on_lock_error: false
      )

      if result.ok?
        halt!
        clear_automatic_rollout_schedule!
      else
        fail!(result.error)
      end
    end
  end

  def disable_automatic_rollout!
    clear_automatic_rollout_schedule!
    update!(automatic_rollout: false)
  end

  def schedule_next_automatic_rollout!
    current = Time.current
    next_update = current + AUTO_ROLLOUT_RUN_INTERVAL
    update!(automatic_rollout_updated_at: current, automatic_rollout_next_update_at: next_update)
    AutomaticUpdateRolloutJob.perform_at(next_update, id, next_update.to_i, current_stage)
  end

  def clear_automatic_rollout_schedule!
    return unless automatic_rollout?
    update!(automatic_rollout_next_update_at: nil)
  end

  def resume_release!
    with_lock do
      return unless may_resume?

      result = rollout(last_rollout_percentage, retry_on_review_fail: true)
      if result.ok?
        resume!
        schedule_next_automatic_rollout! if automatic_rollout?
      else
        fail!(result.error)
      end
    end
  end

  def rollout_active?
    provider.build_active?(submission_channel_id, build_number, raise_on_lock_error: true)
  end

  def pause_release!
    with_lock do
      return unless may_pause?
      return unless automatic_rollout?

      pause!
      clear_automatic_rollout_schedule!
    end
  end

  private

  def fail!(error)
    elog(error, level: :warn)
    errors.add(:base, error)
    event_stamp!(reason: :failed, kind: :error, data: stamp_data)

    return if play_store_submission.fail_with_review_rejected!(error)
    play_store_submission.fail_with_error!(error) if play_store_submission.auto_start_rollout?
  end

  def rollout(value, retry_on_review_fail: false)
    provider.rollout_release(
      submission_channel_id,
      build_number,
      release_version,
      value,
      nil,
      retry_on_review_fail:,
      raise_on_lock_error: false
    )
  end

  def on_start!
    update_external_status
    schedule_next_automatic_rollout! if automatic_rollout?
    super
  end

  def on_resume!
    update_external_status
    super
  end

  def on_complete!
    update_external_status
    super
  end

  def on_halt!
    update_external_status
    event_stamp!(reason: :halted, kind: :error, data: stamp_data)
    notify!("Rollout has been halted", :production_rollout_halted, notification_params)
  end

  def stamp_data
    super.merge(track: submission_channel.name.humanize)
  end

  def find_stage_for_percentage(percentage)
    return next_stage if percentage.nil?

    # Find the stage index where the percentage matches or is just below
    # e.g., for config [10, 50, 100] and percentage 50, return index 1
    config.each_with_index do |stage_percent, idx|
      return idx if percentage.to_f <= stage_percent.to_f
    end
    # If percentage exceeds all stages, return the last stage
    config.size - 1
  end

  def reached_stage?(stage)
    stage >= (config.size - 1)
  end
end
