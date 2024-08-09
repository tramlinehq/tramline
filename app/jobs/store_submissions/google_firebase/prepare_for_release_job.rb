class StoreSubmissions::GoogleFirebase::PrepareForReleaseJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = GoogleFirebaseSubmission.find(submission_id)
    return unless submission.may_finish?
    submission.prepare_for_release!
  end
end
