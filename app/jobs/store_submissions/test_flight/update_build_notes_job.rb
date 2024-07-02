class StoreSubmissions::TestFlight::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = TestFlightSubmission.find(submission_id)
    return unless submission
    # TODO return unless submission.send_notes?

    submission.update_build_notes!
  end
end