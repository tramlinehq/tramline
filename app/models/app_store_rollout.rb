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
class AppStoreRollout < StoreRollout
  include Passportable

  ReleaseNotFullyLive = Class.new(StandardError)
  STATES = STATES.merge(paused: "paused", syncing: "syncing")
  STAMPABLE_REASONS = %w[
    started
    updated
    paused
    resumed
    halted
    completed
    fully_released
    sync_initiated
    sync_completed
    sync_no_changes
    sync_failed
  ]

  belongs_to :app_store_submission, foreign_key: :store_submission_id, inverse_of: :app_store_rollout
  delegate :update_store_info!, to: :store_submission

  aasm safe_state_machine_params(with_lock: false) do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
      transitions from: :created, to: :started
    end

    event :pause do
      transitions from: :started, to: :paused
    end

    event :resume do
      transitions from: :paused, to: :started
    end

    event :halt do
      transitions from: [:started, :paused], to: :halted
    end

    event :complete, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: [:started, :paused], to: :completed
    end

    event :fully_release, after_commit: :on_complete! do
      after { set_completed_at! }
      transitions from: :started, to: :fully_released
    end

    event :start_sync do
      transitions from: [:created, :started, :paused, :halted], to: :syncing
    end

    event :finish_sync do
      transitions from: :syncing, to: :created, guard: :created_before_sync?
      transitions from: :syncing, to: :started, guard: :started_before_sync?
      transitions from: :syncing, to: :paused, guard: :paused_before_sync?
      transitions from: :syncing, to: :halted, guard: :halted_before_sync?
    end
  end

  def controllable_rollout? = false

  def automatic_rollout? = true

  def start_release!
    # return mock_start_app_store_rollout! if sandbox_mode?
    result = provider.start_release(build_number)

    unless result.ok?
      elog(result.error, level: :warn)
      errors.add(:base, result.error)
      return
    end

    if staged_rollout?
      start!
      event_stamp!(reason: :started, kind: :notice, data: stamp_data)
    else
      complete!
    end

    StoreRollouts::AppStore::FindLiveReleaseJob.perform_async(id)
  end

  def track_live_release_status
    return if completed? || fully_released?
    return unless actionable?

    result = provider.find_live_release
    unless result.ok?
      elog(result.error, level: :warn)
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end

    release_info = result.value!
    if release_info.live?(build_number)
      return complete! unless staged_rollout?
      with_lock { update_rollout(release_info) }
      return if release_info.phased_release_complete?
    end

    raise ReleaseNotFullyLive, "Retrying in some time..."
  end

  def halt_release!
    with_lock do
      return unless may_halt?

      result = provider.halt_phased_release
      if result.ok?
        update_store_info!(result.value!)
        halt!
        event_stamp!(reason: :halted, kind: :notice, data: stamp_data)
        notify!("Rollout has been halted", :production_rollout_halted, notification_params)
      else
        elog(result.error, level: :warn)
        errors.add(:base, result.error)
      end
    end
  end

  def release_fully!
    with_lock do
      return unless may_fully_release?

      result = provider.complete_phased_release
      if result.ok?
        update_store_info!(result.value!)
        fully_release!
        event_stamp!(reason: :fully_released, kind: :success, data: stamp_data)
      else
        return complete! if result.error.reason == :phased_release_already_complete
        elog(result.error, level: :warn)
        errors.add(:base, result.error)
      end
    end
  end

  def pause_release!
    with_lock do
      return unless may_pause?

      result = provider.pause_phased_release
      if result.ok?
        update_store_info!(result.value!)
        pause!
        event_stamp!(reason: :paused, kind: :error, data: stamp_data)
        notify!("Rollout has been paused", :production_rollout_paused, notification_params)
      else
        elog(result.error, level: :warn)
        errors.add(:base, result.error)
      end
    end
  end

  def resume_release!
    with_lock do
      return unless may_resume?

      result = provider.resume_phased_release
      if result.ok?
        resume!
        update_rollout(result.value!)
        event_stamp!(reason: :resumed, kind: :notice, data: stamp_data)
        notify!("Rollout has been resumed", :production_rollout_resumed, notification_params)
      else
        elog(result.error, level: :warn)
        errors.add(:base, result.error)
      end
    end
  end

  def sync_from_store!
    return unless may_start_sync?

    previous_status = status
    start_sync!
    event_stamp!(reason: :sync_initiated, kind: :notice, data: stamp_data)

    StoreRollouts::AppStore::SyncStoreStatusJob.perform_async(id, previous_status)
  end

  def syncable?
    !syncing? && may_start_sync?
  end

  private

  attr_accessor :status_before_sync

  def created_before_sync?
    status_before_sync == "created"
  end

  def started_before_sync?
    status_before_sync == "started"
  end

  def paused_before_sync?
    status_before_sync == "paused"
  end

  def halted_before_sync?
    status_before_sync == "halted"
  end

  def update_rollout(release_info)
    update_store_info!(release_info)
    update_stage(release_info.phased_release_stage, finish_rollout: release_info.phased_release_complete?)
  end

  def on_complete!
    event_stamp!(reason: :completed, kind: :success, data: stamp_data)
    super
  end
end
