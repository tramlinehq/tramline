class WorkflowRuns::CancelJob < ApplicationJob
  extend Backoffable
  WorkflowRunNotFound = Class.new(StandardError)

  queue_as :high
  retry_on WorkflowRunNotFound, wait: ->(c) { backoff_in(attempt: c, period: :seconds, type: :linear) }, attempts: 500

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.cancelling?
    raise WorkflowRunNotFound unless workflow_run.workflow_found?

    workflow_run.cancel_external_workflow!
    workflow_run.cancel!
  end
end
