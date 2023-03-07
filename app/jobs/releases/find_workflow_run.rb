class Releases::FindWorkflowRun
  include Sidekiq::Job
  include Loggable

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
    if ex.is_a?(Installations::Errors::WorkflowRunNotFound)
      run = Releases::Step::Run.find(msg["args"].first)
      run.ci_unavailable!
      run.event_stamp!(reason: :ci_unavailable, kind: :error, data: {})
    end
  end

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.release.on_track?
    step_run.ci_start!
  rescue => e
    elog(e)
    raise # TODO: remove this and elog in the retry-kill case
  end
end
