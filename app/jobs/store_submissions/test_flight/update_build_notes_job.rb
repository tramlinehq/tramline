class StoreSubmissions::TestFlight::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = TestFlightSubmission.find(submission_id)
    submission.update_build_notes!
  end
end
