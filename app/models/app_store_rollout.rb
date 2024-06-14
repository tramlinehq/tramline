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
class AppStoreRollout < StoreRollout
  STATES = STATES.merge(paused: "paused")

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: :created, to: :started
      transitions from: :paused, to: :started
      transitions from: :failed, to: :started
    end

    event :pause do
      transitions from: :started, to: :paused
    end

    event :halt do
      transitions from: [:started, :paused, :failed], to: :halted
    end

    event :complete do
      after { "bubble up" }
      transitions from: [:failed, :started, :paused], to: :completed
    end

    event :rollout_fully do
      after { "bubble up" }
      transitions from: [:failed, :started], to: :fully_released
    end

    event :fail do
      transitions from: [:started, :failed, :created], to: :failed
    end
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_phased_release
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

    with_lock do
      result = provider.complete_phased_release
      if result.ok?
        create_or_update_external_release(result.value!)
        rollout_fully!
        # notify!("Staged rollout was accelerated to a full rollout!", :staged_rollout_fully_released, notification_params)
      else
        elog(result.error)
        # run.fail_with_error(result.error)
      end
    end
  end

  def pause_release!
    return unless started?

    with_lock do
      result = provider.pause_phased_release
      if result.ok?
        update_rollout(result.value!)
        pause!
      else
        elog(result.error)
      end
    end
  end

  def resume_release!
    # return unless (paused? && deployment_run.automatic_rollout?) || (stopped? && deployment_run.controllable_rollout?)

    with_lock do
      return unless may_start?
      result = provider.resume_phased_release
      if result.ok?
        update_rollout(result.value!)
        unless completed?
          start!
          # notify!("Staged rollout was resumed!", :staged_rollout_resumed, notification_params)
        end
      else
        elog(result.error)
      end
    end
  end

  private

  def update_rollout(release_info)
    create_or_update_external_release(release_info)
    update_stage(release_info.phased_release_stage, finish_rollout: release_info.phased_release_complete?)
  end

  def create_or_update_external_release(release_info)
    # (run.external_release || run.build_external_release).update(release_info.attributes)
  end
end
