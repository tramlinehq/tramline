class StoreSubmissions::AppStore::SubmitForReviewJob
  include Sidekiq::Job
  extend Backoffable

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    submission.submit!
  end
end
