class StoreSubmissions::TestFlight::FindBuildJob
  include Sidekiq::Job
  include RetryableJob
  include Loggable
  extend Loggable

  self.MAX_RETRIES = 800
  queue_as :high

  def perform(submission_id, retry_args = {})
    submission = TestFlightSubmission.find(submission_id)
    return unless submission.actionable?
    return unless submission.may_submit_for_review?

    submission.find_build.value!
    submission.start_release!
  end

  def backoff_multiplier
    1.minute
  end

  def handle_retries_exhausted(context)
    if context[:last_exception].is_a?(Installations::Error)
      submission = TestFlightSubmission.find(context[:submission_id])
      submission.fail_with_error!(context[:last_exception])
    end
    super
  end
end
