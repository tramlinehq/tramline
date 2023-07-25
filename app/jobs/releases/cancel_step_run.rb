class Releases::CancelStepRun < ApplicationJob
  include Loggable

  queue_as :high

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    return unless step_run.release_platform_run.on_track?

    step_run.cancel!
  end
end
