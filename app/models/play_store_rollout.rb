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
  delegate :deployment_channel_id, :deployment_channel, :update_external_status, to: :store_submission

  STAMPABLE_REASONS = %w[
    started
    updated
    halted
    completed
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
      transitions from: :started, to: :fully_released
    end
  end

  def controllable_rollout? = true

  def automatic_rollout? = false

  def start_release!
    if staged_rollout?
      return mock_start_play_store_rollout! if sandbox_mode?
      move_to_next_stage!
    else
      return mock_complete_play_store_rollout! if sandbox_mode?
      result = rollout(Release::FULL_ROLLOUT_VALUE)
      if result.ok?
        complete!
        event_stamp!(reason: :completed, kind: :success, data: stamp_data)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def move_to_next_stage!
    with_lock do
      return if completed? || fully_released?

      result = rollout(next_rollout_percentage)
      if result.ok?
        update_stage(next_stage, finish_rollout: true)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def release_fully!
    with_lock do
      return unless may_fully_release?

      rollout_value = Release::FULL_ROLLOUT_VALUE
      result = rollout(rollout_value)
      if result.ok?
        fully_release!
        event_stamp!(reason: :fully_released, kind: :success, data: stamp_data)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_release(deployment_channel_id, build_number, version_name, last_rollout_percentage)
      if result.ok?
        halt!
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def resume_release!
    with_lock do
      return unless may_start?

      result = rollout(last_rollout_percentage)
      if result.ok?
        start!
        event_stamp!(reason: :resumed, kind: :notice, data: stamp_data)
        notify!("Rollout was resumed", :production_rollout_resumed, notification_params)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  private

  def rollout(value)
    provider.rollout_release(deployment_channel_id, build_number, version_name, value, nil)
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
    super.merge(track: deployment_channel.name.humanize)
  end
end
