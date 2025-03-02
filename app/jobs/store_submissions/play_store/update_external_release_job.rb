class StoreSubmissions::PlayStore::UpdateExternalReleaseJob < ApplicationJob
  sidekiq_options retry: 30

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(GooglePlayStoreIntegration::LockAcquisitionError)
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 1).to_i
    else
      :kill
    end
  end

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    submission.update_store_info!
  end
end
