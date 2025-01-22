# == Schema Information
#
# Table name: store_rollouts
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  config                  :decimal(8, 5)    default([]), not null, is an Array
#  current_stage           :integer
#  is_staged_rollout       :boolean          default(FALSE)
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#  store_submission_id     :uuid             indexed
#
class PlayStoreRollout < StoreRollout
  include Passportable

  belongs_to :play_store_submission, foreign_key: :store_submission_id, inverse_of: :play_store_rollout
  delegate :submission_channel_id, :submission_channel, :update_external_status, to: :store_submission

  STAMPABLE_REASONS = %w[
    started
    updated
    resumed
    halted
    completed
    failed
    fully_released
  ]

  aasm safe_state_machine_params(with_lock: false) do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
      transitions from: :created, to: :started
      transitions from: :halted, to: :started
    end

    event :halt, after_commit: :on_halt! do
      transitions from: [:started], to: :halted
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

  def automatic_rollout? = false

  def start_release!(retry_on_review_fail: false)
    if staged_rollout?
      # return mock_start_play_store_rollout! if sandbox_mode?
      move_to_next_stage!(retry_on_review_fail:)
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

      result = provider.halt_release(submission_channel_id, build_number, release_version, last_rollout_percentage, retry_on_review_fail: true)
      if result.ok?
        halt!
      else
        fail!(result.error)
      end
    end
  end

  def resume_release!
    with_lock do
      return unless may_start?

      result = rollout(last_rollout_percentage, retry_on_review_fail: true)
      if result.ok?
        start!
        event_stamp!(reason: :resumed, kind: :notice, data: stamp_data)
        notify!("Rollout was resumed", :production_rollout_resumed, notification_params)
      else
        fail!(result.error)
      end
    end
  end

  def rollout_in_progress?
    provider.build_in_progress?(submission_channel_id, build_number)
  end

  private

  def fail!(error)
    elog(error)
    errors.add(:base, error)
    event_stamp!(reason: :failed, kind: :error, data: stamp_data)

    return if play_store_submission.fail_with_review_rejected!(error)
    play_store_submission.fail_with_error!(error) if play_store_submission.auto_rollout?
  end

  def rollout(value, retry_on_review_fail: false)
    provider.rollout_release(submission_channel_id, build_number, release_version, value, nil, retry_on_review_fail:)
  end

  def on_start!
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
end
