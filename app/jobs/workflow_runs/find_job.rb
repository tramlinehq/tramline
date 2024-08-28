class WorkflowRuns::FindJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 25

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Errors::WorkflowRunNotFound)
      backoff_in(attempt: count, period: :minutes).to_i
    else
      elog(exception)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Errors::WorkflowRunNotFound)
      run = WorkflowRun.find(msg["args"].first)
      run.unavailable! if run.may_unavailable?
      elog(ex)
    end
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    workflow_run.find_and_update_external
    workflow_run.found! if workflow_run.may_found?
  end
end
