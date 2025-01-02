class StoreSubmissions::AppStore::UpdateExternalReleaseJob < ApplicationJob
  include Loggable

  queue_as :high
  sidekiq_options retry: 2000

  def perform(submission_id, can_retry: true)
    submission = AppStoreSubmission.find(submission_id)
    submission.update_external_release
  rescue AppStoreSubmission::SubmissionNotInTerminalState => e
    elog(e)
    StoreSubmissions::AppStore::UpdateExternalReleaseJob.set(wait: 5.minutes).perform_async(submission_id, can_retry:) if can_retry
  end
end
