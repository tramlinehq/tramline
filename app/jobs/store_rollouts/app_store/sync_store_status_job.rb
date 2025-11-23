class StoreRollouts::AppStore::SyncStoreStatusJob < ApplicationJob
  sidekiq_options retry: 5

  def perform(rollout_id, previous_status)
    rollout = AppStoreRollout.find(rollout_id)
    return unless rollout.syncing?

    rollout.status_before_sync = previous_status

    result = rollout.provider.find_live_release

    unless result.ok?
      handle_sync_error(rollout, result.error)
      return
    end

    release_info = result.value!
    old_status = previous_status
    old_stage = rollout.current_stage
    old_percentage = rollout.last_rollout_percentage

    # Check if release is live with this build number
    unless release_info.live?(rollout.build_number)
      # Build not live yet, no changes
      rollout.status_before_sync = previous_status
      rollout.finish_sync!
      rollout.event_stamp!(
        reason: :sync_no_changes,
        kind: :notice,
        data: rollout.stamp_data.merge(
          message: "Build not yet live in store"
        )
      )
      return
    end

    # Update store info
    rollout.update_store_info!(release_info)

    # Determine new state
    new_status = map_store_state_to_tramline_state(release_info, rollout)
    new_stage = release_info.staged_rollout? ? release_info.phased_release_stage : nil
    new_percentage = rollout.last_rollout_percentage

    # Track changes
    changes = detect_changes(old_status, new_status, old_stage, new_stage, old_percentage, new_percentage)

    # Update stage if phased release
    if release_info.staged_rollout? && new_stage != old_stage
      rollout.update_stage(new_stage, finish_rollout: release_info.phased_release_complete?)
    end

    # Transition to new state if different
    if new_status && new_status != previous_status
      rollout.status_before_sync = new_status
      rollout.finish_sync!
      rollout.event_stamp!(
        reason: :sync_completed,
        kind: :success,
        data: rollout.stamp_data.merge(
          changes: changes,
          previous_status: old_status,
          new_status: new_status
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
          changes: changes
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

  def map_store_state_to_tramline_state(release_info, rollout)
    return "halted" if release_info.halted?
    return "paused" if release_info.paused?

    if release_info.phased_release_complete? || !rollout.staged_rollout?
      nil # Will be handled by completion logic
    elsif release_info.live?(rollout.build_number)
      "started"
    else
      nil
    end
  end

  def detect_changes(old_status, new_status, old_stage, new_stage, old_percentage, new_percentage)
    changes = []
    changes << "Status: #{old_status} → #{new_status}" if new_status && old_status != new_status
    changes << "Stage: #{old_stage} → #{new_stage}" if new_stage && old_stage != new_stage
    changes << "Rollout: #{old_percentage}% → #{new_percentage}%" if old_percentage != new_percentage
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
