class StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob < ApplicationJob
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 5

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(GoogleFirebaseSubmission::UploadNotComplete)
      backoff_in(attempt: count, period: :minutes, type: :static, factor: 2).to_i
    else
      elog(ex)
      :kill
    end
  end

  def perform(submission_id, op_name)
    submission = GoogleFirebaseSubmission.find(submission_id)
    return unless submission.may_prepare?
    submission.update_upload_status!(op_name)
  end
end
