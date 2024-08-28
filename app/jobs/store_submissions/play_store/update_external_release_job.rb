class StoreSubmissions::PlayStore::UpdateExternalReleaseJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    submission.update_store_info!
  end
end
