class StoreSubmissions::AppStore::UpdateExternalReleaseJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 2000

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(SubmissionNotInTerminalState)
      backoff_in(attempt: count, period: :minutes, type: :static, factor: 5).to_i
    else
      elog(ex)
      :kill
    end
  end

  def perform(submission_id)
    submission = StoreSubmission.find(submission_id)
    submission.update_external_release
  end
end
