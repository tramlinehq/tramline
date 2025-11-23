class StoreSubmissions::AppStore::SyncStoreStatusJob < ApplicationJob
  sidekiq_options retry: 5

  def perform(submission_id, previous_status)
    submission = AppStoreSubmission.find(submission_id)
    return unless submission.syncing?

    submission.status_before_sync = previous_status

    result = submission.provider.find_release(submission.build_number)

    unless result.ok?
      handle_sync_error(submission, result.error)
      return
    end

    release_info = result.value!
    old_store_status = submission.store_status
    old_status = previous_status

    # Update store info
    submission.update_store_info!(release_info)

    # Determine new state based on store release info
    new_status = map_store_state_to_tramline_state(release_info)

    # Track changes
    changes = detect_changes(old_status, new_status, old_store_status, submission.store_status)

    # Transition to new state if different
    if new_status != previous_status
      submission.status_before_sync = new_status
      submission.finish_sync!
      submission.event_stamp!(
        reason: :sync_completed,
        kind: :success,
        data: submission.stamp_data.merge(
          changes: changes,
          previous_status: old_status,
          new_status: new_status
        )
      )
    else
      # No changes detected
      submission.status_before_sync = previous_status
      submission.finish_sync!
      submission.event_stamp!(
        reason: :sync_no_changes,
        kind: :notice,
        data: submission.stamp_data.merge(
          message: "No changes detected in store status"
        )
      )
    end
  rescue => e
    handle_sync_error(submission, e) if submission
    raise
  end

  private

  def map_store_state_to_tramline_state(release_info)
    if release_info.success?
      "approved"
    elsif release_info.review_cancelled?
      "cancelled"
    elsif release_info.review_failed?
      "review_failed"
    elsif release_info.waiting_for_review?
      "submitted_for_review"
    elsif release_info.prepare_for_submission? || release_info.ready_for_review?
      "prepared"
    else
      # Default to current state if uncertain
      nil
    end
  end

  def detect_changes(old_status, new_status, old_store_status, new_store_status)
    changes = []
    changes << "Status: #{old_status} → #{new_status}" if old_status != new_status
    changes << "Store status: #{old_store_status} → #{new_store_status}" if old_store_status != new_store_status
    changes.join(", ")
  end

  def handle_sync_error(submission, error)
    submission.status_before_sync = submission.aasm.from_state
    submission.finish_sync! if submission.may_finish_sync?
    submission.event_stamp!(
      reason: :sync_failed,
      kind: :error,
      data: submission.stamp_data.merge(
        error_message: error.respond_to?(:message) ? error.message : error.to_s
      )
    )
  end
end
