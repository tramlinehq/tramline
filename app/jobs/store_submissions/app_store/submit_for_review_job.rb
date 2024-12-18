class StoreSubmissions::AppStore::SubmitForReviewJob < ApplicationJob
  extend Backoffable

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    submission.submit!
  end
end
