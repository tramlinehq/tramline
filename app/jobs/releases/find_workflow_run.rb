class Releases::FindWorkflowRun < ApplicationJob
  include Loggable

  queue_as :high
  sidekiq_options retry: 25

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Error) && exception.reason == :workflow_run_not_found
      10 * (count + 1)
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :workflow_run_not_found
      run = StepRun.find(msg["args"].first)
      run.ci_unavailable! if run.may_ci_unavailable?
      run.event_stamp!(reason: :ci_workflow_unavailable, kind: :error, data: {})
    end
  end

  def perform(step_run_id)
    step_run = StepRun.find(step_run_id)
    step_run.find_and_update_workflow_run
    step_run.ci_start! if step_run.may_ci_start?
  rescue => e
    elog(e)
    raise # TODO: remove this and elog in the retry-kill case
  end
end
