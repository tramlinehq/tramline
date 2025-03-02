class StoreSubmissions::PlayStore::UploadJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 50

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
    return unless submission.may_start_prepare?
    submission.upload_build!
  end
end
