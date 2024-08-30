class StoreSubmissions::AppStore::RemoveFromReviewJob
  include Sidekiq::Job
  extend Backoffable

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    return unless submission&.may_cancel?
    submission.remove_from_review!
  end
end
