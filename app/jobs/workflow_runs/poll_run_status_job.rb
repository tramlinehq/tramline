class WorkflowRuns::PollRunStatusJob < ApplicationJob
  queue_as :high

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return unless workflow_run.started?

    WorkflowProcessors::WorkflowRunV2.process(workflow_run)
  end
end
