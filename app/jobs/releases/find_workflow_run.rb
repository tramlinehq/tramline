class Releases::FindWorkflowRun
  include Sidekiq::Job
  include RetryableJob
  include Loggable

  self.MAX_RETRIES = 25
  queue_as :high

  def perform(step_run_id, retry_args = {})
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    if retry_count > self.MAX_RETRIES
      on_retries_exhausted(step_run_id:)
      return
    end

    begin
      step_run = StepRun.find(step_run_id)
      step_run.find_and_update_workflow_run
      step_run.ci_start! if step_run.may_ci_start?
    rescue => e
      elog(e)

      if e.is_a?(Installations::Error) && e.reason == :workflow_run_not_found
        retry_with_backoff(e, {step_run_id:, retry_count:})
        raise e
      else
        raise
      end
    end
  end

  def on_retries_exhausted(retry_args)
    retry_args = {step_run_id: retry_args} unless retry_args.is_a?(Hash)

    run = StepRun.find(retry_args[:step_run_id])
    run.ci_unavailable! if run.may_ci_unavailable?
    run.event_stamp!(reason: :ci_workflow_unavailable, kind: :error, data: {})
  end
end
