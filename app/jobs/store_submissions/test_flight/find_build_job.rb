class StoreSubmissions::TestFlight::FindBuildJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 800

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :build_not_found
      Rails.logger.debug { "TestFlight build not found, retrying: #{ex.message}" }
      backoff_in(attempt: count, period: :minutes, type: :static, factor: 1).to_i
    else
      elog(ex)
      :kill
    end
  end

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
