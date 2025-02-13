class StoreSubmissions::AppStore::RemoveFromReviewJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    return unless submission&.may_cancel?
    submission.remove_from_review!
  end
end
