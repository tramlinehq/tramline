class Releases::CancelWorkflowRun < ApplicationJob
  include Loggable

  queue_as :high

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    step_run.cancel_ci_workflow!
  end
end
