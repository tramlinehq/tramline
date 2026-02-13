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

    # can't find the build, try again
    result = provider.find_release(build_number)
    unless result.ok?
      elog(result.error, level: :warn)
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end

    # build isn't ready yet, try again
    release_info = result.value!
    unless release_info.live?(build_number)
      raise ReleaseNotFullyLive, "Retrying in some time..."
    end

    with_lock do
      # rollout is completed on the store — regardless of what we think is true
      if !release_info.phased_release_available? || release_info.phased_release_complete?
        transition_to_complete_state(release_info)
        return
      end

      if release_info.phased_release_active?
        if created?
          # rollout is in created in our system, but has started on the store
          # (eg. auto-start from ASC, or out-of-band phased release)
          transition_to_started_state(staged_rollout? ? release_info : nil)
        elsif staged_rollout?
          # rollout is started in our system, update ourselves with the latest
          update_rollout(release_info)
        end
      end
    end

    # continue polling, any terminal transitions will be guarded off the next time
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

  # Transition to completed state when the store has already finished the rollout
  # Either phased release is complete or no phased release was configured on ASC
  def transition_to_complete_state(release_info)
    start! if created?
    update_rollout(release_info) if release_info.phased_release_available?
    complete! unless completed?
  end

  # If release_info is provided (auto-start flow), also update the rollout stage
  # If not provided (manual flow), just transition state
  def transition_to_started_state(release_info = nil)
    start!
    event_stamp!(reason: :started, kind: :notice, data: stamp_data)
    update_rollout(release_info) if release_info
  end

  def update_rollout(release_info)
    update_store_info!(release_info)
    update_stage(release_info.phased_release_stage, finish_rollout: release_info.phased_release_complete?)
  end
end
