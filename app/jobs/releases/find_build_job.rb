class Releases::FindBuildJob
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
    if ex.is_a?(Installations::Error) && ex.reason == :build_not_found
      run = Releases::Step::Run.find(msg["args"].first)
      run.build_not_found!
      run.event_stamp!(reason: :build_not_found_in_store, kind: :error, data: {version: run.build_version})
    end
  end

  def perform(step_run_id)
    run = Releases::Step::Run.find(step_run_id)
    return unless run.release.on_track?
    run.find_build.value!
    run.build_found!
    run.event_stamp!(reason: :build_found_in_store, kind: :notice, data: {version: run.build_version})
  end
end
