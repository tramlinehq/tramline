class WorkflowProcessors::WorkflowRun < ApplicationJob
  class WorkflowRunNotFound < StandardError; end

  queue_as :high

  # FIXME: check if train is still on_track
  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.ci_workflow_started?
    workflow_run = step_run.get_workflow_run
    raise WorkflowRunNotFound unless workflow_run.present?
    WorkflowProcessors::Github::WorkflowRun.process(step_run, workflow_run)
  end
end
