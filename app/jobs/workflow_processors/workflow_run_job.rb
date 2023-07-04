class WorkflowProcessors::WorkflowRunJob < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    run = StepRun.find(step_run_id)
    return unless run.release_platform_run.on_track?
    return unless run.ci_workflow_started?

    WorkflowProcessors::WorkflowRun.process(run)
  end
end
