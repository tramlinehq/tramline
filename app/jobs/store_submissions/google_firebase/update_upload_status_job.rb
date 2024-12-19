class StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob
  include Sidekiq::Job
  include RetryableJob
  include Loggable
  extend Loggable

  self.MAX_RETRIES = 5
  queue_as :high

  def perform(submission_id, op_name, retry_args = {})
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    submission = GoogleFirebaseSubmission.find(submission_id)
    return unless submission.may_prepare?

    begin
      submission.update_upload_status!(op_name)
    rescue GoogleFirebaseSubmission::UploadNotComplete => e
      retry_with_backoff(e, {
        submission_id: submission_id,
        op_name: op_name,
        retry_count: retry_count
      })
    rescue => e
      elog(e)
      raise
    end
  end

  def backoff_multiplier
    2.minutes
  end
end
