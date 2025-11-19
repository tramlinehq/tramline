class StoreSubmissions::PlayStore::SyncStoreStatusJob < ApplicationJob
  sidekiq_options retry: 5

  def perform(submission_id, previous_status)
    submission = PlayStoreSubmission.find(submission_id)
    return unless submission.syncing?

    submission.status_before_sync = previous_status

    old_store_status = submission.store_status
    old_status = previous_status

    # Update store info (finds build in production track)
    submission.update_store_info!

    # Track changes
    changes = detect_changes(old_status, submission.status, old_store_status, submission.store_status)

    # For Play Store, the status generally stays as "prepared" once it's there
    # But we sync the store_status which reflects the actual Play Store state
    if changes.present?
      submission.status_before_sync = previous_status
      submission.finish_sync!
      submission.event_stamp!(
        reason: :sync_completed,
        kind: :success,
        data: submission.stamp_data.merge(
          changes: changes,
          store_status: submission.store_status
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
