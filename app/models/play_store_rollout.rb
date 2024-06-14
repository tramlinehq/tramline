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
class PlayStoreRollout < StoreRollout
  aasm safe_state_machine_params.merge(requires_lock: false) do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: :created, to: :started
      transitions from: :halted, to: :started
      transitions from: :failed, to: :started
    end

    event :halt do
      transitions from: [:started, :failed], to: :halted
    end

    event :complete do
      transitions from: :started, to: :completed
    end

    event :rollout_fully do
      transitions from: :completed, to: :fully_released
    end

    event :fail do
      transitions from: [:started, :failed, :created], to: :failed
    end
  end

  def pausable? = false

  def resumable? = halted?

  def move_to_next_stage!
    with_lock do
      return if completed? || fully_released?

      result = rollout(next_rollout_percentage)
      if result.ok?
        update_stage(next_stage, finish_rollout: true)
      else
        fail!
        elog(result.error)
      end
    end
  end

  def rollout_fully
    with_lock do
      return unless may_rollout_fully?

      rollout_value = one_percent_beta_release? ? BigDecimal("1") : Deployment::FULL_ROLLOUT_VALUE
      result = rollout(rollout_value)
      if result.ok?
        rollout_fully!
        # notify!("Staged rollout was accelerated to a full rollout!", :staged_rollout_fully_released, notification_params)
      else
        elog(result.error)
      end
    end
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_release(release_channel, build_number, version_name, last_rollout_percentage)
      if result.ok?
        halt!
        # notify!("Release was halted!", :staged_rollout_halted, notification_params)
      else
        elog(result.error)
      end
    end
  end

  def resume_release!
    with_lock do
      return unless may_start?

      result = rollout(last_rollout_percentage)
      if result.ok?
        start!
        # notify!("Release was resumed!", :staged_rollout_resumed, notification_params)
      else
        elog(result.error)
      end
    end
  end

  private

  def rollout(value)
    provider.rollout_release(release_channel, build_number, version_name, value, nil)
  end
end
