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
class AppStoreRollout < StoreRollout
  ReleaseNotFullyLive = Class.new(StandardError)
  STATES = STATES.merge(paused: "paused")

  aasm safe_state_machine_params(with_lock: false) do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
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

    event :complete, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: [:failed, :started, :paused], to: :completed
    end

    event :rollout_fully, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: [:failed, :started], to: :fully_released
    end
  end

  def track_live_release_status
    return if terminal?

    result = provider.find_live_release
    unless result.ok?
      elog(result.error)
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end

    release_info = result.value!
    if release_info.live?(build_number)
      return complete! unless staged_rollout?
      with_lock { update_rollout(release_info) }
      notify!("Phased release was updated!", :staged_rollout_updated, notification_params)
      return if release_info.phased_release_complete?
    end

    raise ReleaseNotFullyLive, "Retrying in some time..."
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_phased_release
      if result.ok?
        halt!
        notify!("Phased release was halted!", :staged_rollout_halted, notification_params)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def fully_release!
    with_lock do
      return unless may_rollout_fully?

      result = provider.complete_phased_release
      if result.ok?
        update_store_info!(result.value!)
        rollout_fully!
        notify!("Phased release was accelerated to a full rollout!", :staged_rollout_fully_released, notification_params)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def pause_release!
    with_lock do
      return unless may_pause?

      result = provider.pause_phased_release
      if result.ok?
        update_rollout(result.value!)
        pause!
        notify!("Phased release was paused!", :staged_rollout_paused, notification_params)
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  def resume_release!
    with_lock do
      return unless may_start?

      result = provider.resume_phased_release
      if result.ok?
        update_rollout(result.value!)
        unless completed?
          start!
          notify!("Phased release was resumed!", :staged_rollout_resumed, notification_params)
        end
      else
        elog(result.error)
        errors.add(:base, result.error)
      end
    end
  end

  private

  def on_start!
    production_release.rollout_started!
    StoreRollouts::AppStore::FindLiveReleaseJob.perform_async(id)
  end

  def update_rollout(release_info)
    update_store_info!(release_info)
    update_stage(release_info.phased_release_stage, finish_rollout: release_info.phased_release_complete?)
  end
end
