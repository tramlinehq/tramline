class StoreSubmissions::AppStore::PrepareForReleaseJob
  include Sidekiq::Job
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 3

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(AppStoreSubmission::PreparedVersionNotFoundError)
      backoff_in(attempt: count, period: :minutes, type: :static, factor: 1).to_i
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    submission = AppStoreSubmission.find(msg["args"].first)
    submission.fail_with_error!(ex)
  end

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    submission.prepare_for_release!
  end
end
