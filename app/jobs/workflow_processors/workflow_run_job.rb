class WorkflowProcessors::WorkflowRunJob < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    run = Releases::Step::Run.find(step_run_id)
    return unless run.release.on_track?
    return unless run.ci_workflow_started?

    WorkflowProcessors::WorkflowRun.process(run)
  end
end
