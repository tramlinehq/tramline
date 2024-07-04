class StoreSubmissions::GoogleFirebase::UploadJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = GoogleFirebaseSubmission.find(submission_id)
    return unless submission.may_prepare?
    submission.upload_build!
  end
end
