class StoreSubmissions::AppStore::FindBuildJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 8

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :build_not_found
      backoff_in(attempt: count, period: :minutes).to_i
    else
      elog(ex)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error)
      submission = AppStoreSubmission.find(msg["args"].first)
      submission.fail_with_error!(ex)
    end
  end

  def perform(submission_id)
    submission = AppStoreSubmission.find(submission_id)
    return unless submission.actionable?
    return unless submission.may_start_prepare?

    submission.find_build.value!
    submission.prepare_for_release!
  end
end
