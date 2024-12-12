class Releases::FindBuildJob
  include Sidekiq::Job
  include RetryableJob

  queue_as :high

  def perform(step_run_id, retry_args = {})
    # Normalize retry arguments
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    # If retry count exceeds max retries, handle exhausted retries
    if retry_count > self.MAX_RETRIES
      on_retries_exhausted(step_run_id:, retry_count:)
      return
    end

    run = StepRun.find(step_run_id)
    return unless run.active?

    begin
      run.find_build.value!
      run.build_found!
      run.event_stamp!(reason: :build_found_in_store, kind: :notice, data: {version: run.build_version})
    rescue Installations::Error => e
      # Specific handling for build not found error
      if e.respond_to?(:reason) && e.reason == :build_not_found
        retry_with_backoff(e, {step_run_id:, retry_count:})
      end

      # Re-raise the original error
      raise
    end
  end

  def on_retries_exhausted(retry_args)
    # Ensure we always have a hash of arguments
    retry_args = {step_run_id: retry_args} if retry_args.is_a?(Integer)

    # Custom logic when retries are exhausted (e.g., logging, alerts)
    run = StepRun.find(retry_args[:step_run_id])
    run.build_not_found!
    run.event_stamp!(reason: :build_not_found_in_store, kind: :error, data: {version: run.build_version})
  end
end
