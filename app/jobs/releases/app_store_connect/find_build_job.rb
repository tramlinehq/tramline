class Releases::AppStoreConnect::FindBuildJob
  include Sidekiq::Job
  include Loggable

  queue_as :high
  sidekiq_options retry: 5

  # goes like: 60, 120, 270...
  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Errors::BuildNotFoundInStore)
      30 * (count**2)
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Errors::BuildNotFoundInStore)
      run = Releases::Step::Run.find(msg["args"].first)
      run.build_not_found!
      run.event_stamp!(reason: :build_not_found_in_store, kind: :error, data: {version: run.build_version})
    end
  end

  def perform(step_run_id)
    run = Releases::Step::Run.find(step_run_id)
    return unless run.release.on_track?
    run.build_found! if run.find_build.found?
  rescue => e
    elog(e)
    raise
  end
end
