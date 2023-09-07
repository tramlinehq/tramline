class Releases::TriggerWorkflowRunJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.active?
    return step_run.cancel! unless step_run.commit.applicable?

    step_run.trigger_ci_worfklow_run!
  end
end
