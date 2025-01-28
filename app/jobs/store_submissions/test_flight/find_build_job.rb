class StoreSubmissions::TestFlight::FindBuildJob < ApplicationJob
  include RetryableJob
  queue_as :high

  enduring_retry_on Installations::Error,
    reason: :build_not_found,
    max_attempts: 800,
    backoff: {period: :minutes, type: :static, factor: 1}

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error)
      submission = TestFlightSubmission.find(msg["args"].first)
      submission.fail_with_error!(ex)
    end
  end

  def perform(submission_id)
    submission = TestFlightSubmission.find(submission_id)
    return unless submission.actionable?
    return unless submission.may_submit_for_review?

    submission.find_build.value!
    submission.start_release!
  end
end
