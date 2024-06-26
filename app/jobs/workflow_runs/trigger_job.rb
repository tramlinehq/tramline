class WorkflowRuns::TriggerJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return workflow_run.cancel! unless workflow_run.commit.applicable?

    workflow_run.trigger_external_run!
  end
end
