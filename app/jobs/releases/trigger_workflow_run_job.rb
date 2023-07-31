class Releases::TriggerWorkflowRunJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.active?

    step_run.trigger_ci!
  end
end
