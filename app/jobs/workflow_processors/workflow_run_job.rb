class WorkflowProcessors::WorkflowRunJob < ApplicationJob
  class WorkflowRunNotFound < StandardError; end

  sidekiq_options retry: 0
  queue_as :high

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.release.on_track?
    return unless step_run.ci_workflow_started?

    step_run
      .get_workflow_run
      .tap { |workflow_run| raise WorkflowRunNotFound if workflow_run.blank? }
      .then { |workflow_run| WorkflowProcessors::WorkflowRun.process(step_run, workflow_run) }
  end
end
