class WorkflowProcessors::WorkflowRun < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.release.on_track?
    return unless step_run.ci_workflow_started?
    WorkflowProcessors::Github::WorkflowRun.process(step_run)
  end
end
