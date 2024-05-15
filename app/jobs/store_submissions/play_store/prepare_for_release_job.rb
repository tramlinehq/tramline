class StoreSubmissions::PlayStore::PrepareForReleaseJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    submission.prepare_for_release!
  end
end
