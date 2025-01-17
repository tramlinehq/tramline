class StoreSubmissions::AppStore::FindBuildJob
  MAX_RETRIES = 8
  include Sidekiq::Job
  include Loggable
  include Backoffable

  queue_as :high

  def perform(submission_id, retry_count = 0)
    submission = AppStoreSubmission.find(submission_id)

    return unless submission.actionable?

    begin
      submission.find_build.value!
      submission.prepare_for_release!
    rescue Installations::Error => ex
      raise unless ex.reason == :build_not_found
      if retry_count >= MAX_RETRIES
        log_and_fail(ex, submission)
      else
        wait_time = backoff_in(attempt: retry_count + 1, period: :minutes, type: :static, factor: 1).to_i
        Rails.logger.debug { "Build not found for submission #{submission_id}, retrying in #{wait_time} seconds." }
        self.class.perform_in(wait_time.seconds, submission_id, retry_count + 1)
      end
    rescue => ex
      log_and_fail(ex, submission)
    end
  end

  private

  def log_and_fail(ex, submission)
    elog(ex)
    submission.fail_with_error!(ex)
  end
end
