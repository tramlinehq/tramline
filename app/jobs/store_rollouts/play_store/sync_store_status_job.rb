class StoreRollouts::PlayStore::SyncStoreStatusJob < ApplicationJob
  sidekiq_options retry: 5

  def perform(rollout_id, previous_status)
    rollout = PlayStoreRollout.find(rollout_id)
    return unless rollout.syncing?

    rollout.status_before_sync = previous_status

    # Get current track info from Play Store
    track_info = rollout.provider.find_build_in_track(
      rollout.submission_channel_id,
      rollout.build_number,
      raise_on_lock_error: true
    )

    unless track_info
      # Build not found in track
      rollout.status_before_sync = previous_status
      rollout.finish_sync!
      rollout.event_stamp!(
        reason: :sync_no_changes,
        kind: :notice,
        data: rollout.stamp_data.merge(
          message: "Build not found in production track"
        )
      )
      return
    end

    old_status = previous_status
    old_stage = rollout.current_stage
    old_percentage = rollout.last_rollout_percentage

    # Determine state and percentage from store
    store_status = track_info[:status] # "draft", "inProgress", "completed", "halted"
    store_percentage = track_info[:user_fraction]&.*(100) || 100.0

    # Map store state to Tramline state
    new_status = map_store_state_to_tramline_state(store_status)

    # Find closest stage for the percentage
    new_stage = find_closest_stage(store_percentage, rollout.config) if rollout.staged_rollout?

    # Track changes
    changes = detect_changes(old_status, new_status, old_stage, new_stage, old_percentage, store_percentage)

    # Update stage if changed and staged rollout
    if rollout.staged_rollout? && new_stage && new_stage != old_stage
      rollout.update_stage(new_stage, finish_rollout: store_percentage >= 100.0)
    end

    # Transition to new state if different
    if new_status && new_status != previous_status
      rollout.status_before_sync = new_status
      rollout.finish_sync!

      # If halted in store, halt in Tramline
      rollout.halt! if new_status == "halted" && rollout.may_halt?

      rollout.event_stamp!(
        reason: :sync_completed,
        kind: :success,
        data: rollout.stamp_data.merge(
          changes: changes,
          previous_status: old_status,
          new_status: new_status,
          store_percentage: store_percentage
        )
      )
    elsif changes.present?
      # Stage/percentage changed but not status
      rollout.status_before_sync = previous_status
      rollout.finish_sync!
      rollout.event_stamp!(
        reason: :sync_completed,
        kind: :success,
        data: rollout.stamp_data.merge(
          changes: changes,
          store_percentage: store_percentage
        )
      )
    else
      # No changes detected
      rollout.status_before_sync = previous_status
      rollout.finish_sync!
      rollout.event_stamp!(
        reason: :sync_no_changes,
        kind: :notice,
        data: rollout.stamp_data.merge(
          message: "No changes detected in store rollout"
        )
      )
    end
  rescue => e
    handle_sync_error(rollout, e) if rollout
    raise
  end

  private

  def map_store_state_to_tramline_state(store_status)
    case store_status
    when "halted"
      "halted"
    when "inProgress"
      "started"
    when "completed"
      nil # Keep current state or handle completion
    when "draft"
      "created"
    else
      nil
    end
  end

  def find_closest_stage(percentage, config)
    return nil if config.blank?

    # Find the stage index where the config percentage is closest to the store percentage
    config.each_with_index do |stage_percentage, index|
      return index if stage_percentage >= percentage
    end

    # If we're beyond all configured stages, return the last stage
    config.length - 1
  end

  def detect_changes(old_status, new_status, old_stage, new_stage, old_percentage, new_percentage)
    changes = []
    changes << "Status: #{old_status} → #{new_status}" if new_status && old_status != new_status
    changes << "Stage: #{old_stage} → #{new_stage}" if new_stage && old_stage != new_stage

    # Format percentages properly
    old_perc_fmt = old_percentage.is_a?(Numeric) ? "#{old_percentage.round(2)}%" : old_percentage.to_s
    new_perc_fmt = new_percentage.is_a?(Numeric) ? "#{new_percentage.round(2)}%" : new_percentage.to_s
    changes << "Rollout: #{old_perc_fmt} → #{new_perc_fmt}" if old_percentage.to_f != new_percentage.to_f

    changes.join(", ")
  end

  def handle_sync_error(rollout, error)
    rollout.status_before_sync = rollout.aasm.from_state
    rollout.finish_sync! if rollout.may_finish_sync?
    rollout.event_stamp!(
      reason: :sync_failed,
      kind: :error,
      data: rollout.stamp_data.merge(
        error_message: error.respond_to?(:message) ? error.message : error.to_s
      )
    )
  end
end
