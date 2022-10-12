class Releases::Step::FindWorkflowRun
  include Sidekiq::Job

  queue_as :high
  sidekiq_options retry: 2

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Errors::WorkflowRunNotFound)
      10 * (count + 1)
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    Releases::Step::Run.find(msg["args"].first).ci_unavailable! if ex.is_a?(Installations::Errors::WorkflowRunNotFound)
  end

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.release.on_track?
    step_run.ci_start!
  rescue => e
    Sentry.capture_exception(e)
    raise
  end
end
