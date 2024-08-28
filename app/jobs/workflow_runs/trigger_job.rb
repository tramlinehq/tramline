class WorkflowRuns::TriggerJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(workflow_run_id, retrigger: false)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return unless workflow_run.may_initiated?

    workflow_run.trigger!(retrigger:)
  end
end
