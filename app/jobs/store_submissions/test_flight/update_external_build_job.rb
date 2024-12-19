class StoreSubmissions::TestFlight::UpdateExternalBuildJob
  include Sidekiq::Job
  include RetryableJob
  include Loggable
  extend Loggable

  self.MAX_RETRIES = 2000
  queue_as :high

  def perform(submission_id, retry_args = {})
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    submission = TestFlightSubmission.find(submission_id)
    return unless submission.may_finish?

    begin
      submission.update_external_release
    rescue TestFlightSubmission::SubmissionNotInTerminalState => e
      retry_with_backoff(e, {
        submission_id: submission_id,
        retry_count: retry_count
      })
    rescue => e
      elog(e)
      raise
    end
  end

  def backoff_multiplier
    5.minutes
  end
end
