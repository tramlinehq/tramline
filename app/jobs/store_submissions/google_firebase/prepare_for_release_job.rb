class StoreSubmissions::GoogleFirebase::PrepareForReleaseJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = FirebaseSubmission.find(submission_id)
    submission.prepare_for_release!
  end
end
