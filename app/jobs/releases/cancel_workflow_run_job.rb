class Releases::CancelWorkflowRunJob < ApplicationJob
  extend Backoffable
  WorkflowRunNotFound = Class.new(StandardError)

  queue_as :high
  retry_on WorkflowRunNotFound, wait: ->(c) { backoff_in(attempt: c, period: :seconds, type: :linear) }, attempts: 500

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.cancelling?
    raise WorkflowRunNotFound unless step_run.workflow_found?

    Rails.logger.debug { "Cancelling workflow for step run - #{step_run_id}" }
    step_run.cancel_ci_workflow!
    step_run.cancel!
  end
end
