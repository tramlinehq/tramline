class WorkflowRuns::FindJob
  include Sidekiq::Job
  include Loggable

  queue_as :high
  sidekiq_options retry: 25

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Errors::WorkflowRunNotFound)
      10 * (count + 1)
    else
      elog(exception)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Errors::WorkflowRunNotFound)
      run = StepRun.find(msg["args"].first)
      run.ci_unavailable! if run.may_ci_unavailable?
      run.event_stamp!(reason: :ci_workflow_unavailable, kind: :error, data: {})
      elog(ex)
    end
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    workflow_run.find_and_update_external
    workflow_run.start! if workflow_run.may_start?
  end
end
