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
class AppStoreRollout < StoreRollout
  include Passportable

  ReleaseNotFullyLive = Class.new(StandardError)
  STATES = STATES.merge(paused: "paused")
  STAMPABLE_REASONS = %w[
    started
    updated
    paused
    resumed
    halted
    completed
    fully_released
  ]

  belongs_to :app_store_submission, foreign_key: :store_submission_id, inverse_of: :app_store_rollout
  delegate :update_store_info!, to: :store_submission
  delegate :auto_start_rollout?, to: :app_store_submission

  after_create_commit :start_polling_for_auto_started_rollout

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
  end

  def controllable_rollout? = false

  def start_release!
    # return mock_start_app_store_rollout! if sandbox_mode?
    result = provider.start_release(build_number)

    unless result.ok?
      elog(result.error, level: :warn)
      errors.add(:base, result.error)
      return
    end

    transition_to_started_state
    StoreRollouts::AppStore::FindLiveReleaseJob.perform_async(id)
  end

  def track_live_release_status
    return if completed? || fully_released?
    return unless actionable?

    release_info = fetch_live_release_info

    unless release_info.live?(build_number)
      # Release is not live yet, continue polling
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end

    # Release is live, transition to appropriate state
    if created?
      # Auto-start flow: Apple auto-started the rollout after approval
      transition_to_started_state(release_info)
    else
      # Manual flow: rollout was already started, just update status
      transition_to_live_state(release_info)
    end

    # For non-staged rollouts, we're done (completed in transition methods)
    return unless staged_rollout?

    # For staged rollouts, check if phased release is complete
    return if release_info.phased_release_complete?

    # Staged rollout still in progress, continue polling
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
      else
        elog(result.error, level: :warn)
        errors.add(:base, result.error)
      end
    end
  end

  private

  def start_polling_for_auto_started_rollout
    # If auto_start_rollout is enabled, Apple will automatically start the rollout after approval
    # Start polling to detect when it goes live and transition our state
    StoreRollouts::AppStore::FindLiveReleaseJob.perform_async(id) if auto_start_rollout?
  end

  def fetch_live_release_info
    result = provider.find_live_release
    unless result.ok?
      elog(result.error, level: :warn)
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end
    result.value!
  end

  # Transition to live state when rollout is already started (manual start_release! was called)
  def transition_to_live_state(release_info)
    if staged_rollout?
      update_rollout(release_info)
    else
      complete!
    end
  end

  # Transition to started state
  # If release_info is provided (auto-start flow), also update the rollout stage
  # If not provided (manual flow), just transition state
  def transition_to_started_state(release_info = nil)
    if staged_rollout?
      start!
      event_stamp!(reason: :started, kind: :notice, data: stamp_data)
      update_rollout(release_info) if release_info
    else
      complete!
    end
  end

  def update_rollout(release_info)
    update_store_info!(release_info)
    update_stage(release_info.phased_release_stage, finish_rollout: release_info.phased_release_complete?)
  end
end
