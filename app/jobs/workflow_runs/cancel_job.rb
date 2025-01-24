class WorkflowRuns::CancelJob < ApplicationJob
  WorkflowRunNotFound = Class.new(StandardError)

  sidekiq_options queue: :high, retry: 500

  sidekiq_retry_in do |count, exception|
    backoff_in(attempt: count, period: :seconds, type: :linear) if exception.is_a?(WorkflowRunNotFound)
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.cancelling?
    raise WorkflowRunNotFound unless workflow_run.workflow_found?

    workflow_run.cancel_external_workflow!
    workflow_run.cancel!
  end
end
