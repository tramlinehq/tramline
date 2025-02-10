class StoreSubmissions::TestFlight::UpdateExternalBuildJob < ApplicationJob
  prepend Reenqueuer
  queue_as :high

  enduring_retry_on TestFlightSubmission::SubmissionNotInTerminalState,
    max_attempts: 2000,
    backoff: {period: :minutes, type: :static, factor: 5}

  def perform(submission_id)
    submission = TestFlightSubmission.find(submission_id)
    return unless submission.may_finish?

    submission.update_external_release
  end
end
