class WorkflowProcessors::WorkflowRunJob < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    run = StepRun.find(step_run_id)
    return unless run.platform_release.on_track?
    return unless run.ci_workflow_started?

    WorkflowProcessors::WorkflowRun.process(run)
  end
end
