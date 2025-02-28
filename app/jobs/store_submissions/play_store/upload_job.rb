class StoreSubmissions::PlayStore::UploadJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 25

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(GooglePlayStoreIntegration::LockAcquisitionError)
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 2).to_i
    else
      :kill
    end
  end

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    return unless submission.may_start_prepare?
    submission.upload_build!
  end
end
