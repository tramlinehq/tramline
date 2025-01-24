class StoreSubmissions::AppStore::SubmitForReviewJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    submission.submit!
  end
end
