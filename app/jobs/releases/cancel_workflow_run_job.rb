class Releases::CancelWorkflowRunJob < ApplicationJob
  extend Backoffable
  WorkflowRunNotFound = Class.new(StandardError)

  queue_as :high
  sidekiq_options retry: 500

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(WorkflowRunNotFound)
      backoff_in(attempt: count, period: :seconds, type: :linear).to_i
    else
      :kill
    end
  end

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.cancelling?
    raise WorkflowRunNotFound unless step_run.workflow_found?

    Rails.logger.debug { "Cancelling workflow for step run - #{step_run_id}" }
    step_run.cancel_ci_workflow!
    step_run.cancel!
  end
end
