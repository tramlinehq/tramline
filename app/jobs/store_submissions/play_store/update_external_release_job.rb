class StoreSubmissions::PlayStore::UpdateExternalReleaseJob < ApplicationJob
  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    submission.update_store_info!
  end
end
