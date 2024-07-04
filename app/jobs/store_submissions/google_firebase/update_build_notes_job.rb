class StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(submission_id, release_name)
    submission = GoogleFirebaseSubmission.find(submission_id)
    return unless submission.send_notes?
    submission.update_build_notes!(release_name)
  end
end
