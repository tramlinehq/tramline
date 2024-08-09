class StoreSubmissions::PlayStore::UploadJob < ApplicationJob
  queue_as :high

  def perform(submission_id)
    submission = PlayStoreSubmission.find(submission_id)
    return unless submission.may_start_prepare?
    submission.upload_build!
  end
end
