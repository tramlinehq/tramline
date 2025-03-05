class StoreSubmissions::PlayStore::PrepareForReleaseJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 30

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(GooglePlayStoreIntegration::LockAcquisitionError)
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 1).to_i
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(GooglePlayStoreIntegration::LockAcquisitionError)
      submission = PlayStoreSubmission.find(msg["args"].first)
      submission.fail_with_error!(ex)
    end
  end

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    submission.prepare_for_release!
  end
end
