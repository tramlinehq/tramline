class StoreSubmissions::AppStore::FindBuildJob < ApplicationJob
  include RetryableJob
  queue_as :high

  enduring_retry_on Installations::Error,
    reason: :build_not_found,
    max_attempts: 8,
    backoff: {period: :minutes, type: :static, factor: 1}

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error)
      submission = AppStoreSubmission.find(msg["args"].first)
      submission.fail_with_error!(ex)
    end
  end

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    return unless submission.actionable?

    submission.find_build.value!
    submission.prepare_for_release!
  end
end
