class Releases::CancelWorkflowRun < ApplicationJob
  include Loggable

  queue_as :high

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.release_platform_run.on_track?

    step_run.with_lock do
      return unless step_run.ci_workflow_started?
      step_run.cancel_ci_workflow!
    end
  end
end
