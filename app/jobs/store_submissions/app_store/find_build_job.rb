class StoreSubmissions::AppStore::FindBuildJob
  include Sidekiq::Job
  include RetryableJob

  queue_as :high

  def perform(submission_id, retry_args = {})
    # Normalize retry arguments
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    # If retry count exceeds max retries, handle exhausted retries
    if retry_count > self.MAX_RETRIES
      on_retries_exhausted(submission_id: submission_id, retry_count: retry_count)
      return
    end

    submission = AppStoreSubmission.find(submission_id)
    return unless submission.actionable?

    begin
      submission.find_build.value!
      submission.prepare_for_release!
    rescue Installations::Error => e
      # Specific handling for build not found error
      if e.respond_to?(:reason) && e.reason == :build_not_found
        retry_with_backoff(e, {submission_id: submission_id, retry_count: retry_count})
      end

      # Re-raise the original error
      raise
    end
  end

  def on_retries_exhausted(retry_args)
    # Ensure we always have a hash of arguments
    retry_args = {submission_id: retry_args} if retry_args.is_a?(Integer)

    submission = AppStoreSubmission.find(retry_args[:submission_id])
    submission.fail_with_error!(Installations::Error.new("Build not found after maximum retries", reason: :build_not_found))
  end
end
