class WorkflowRuns::FindJob
  include Sidekiq::Job
  include RetryableJob
  include Loggable
  extend Loggable

  self.MAX_RETRIES = 25
  queue_as :high

  def perform(workflow_run_id, retry_args = {})
    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    workflow_run = WorkflowRun.find(workflow_run_id)
    begin
      workflow_run.find_and_update_external
      workflow_run.found! if workflow_run.may_found?
    rescue Installations::Error => e
      if e.reason == :workflow_run_not_found
        retry_with_backoff(e, {
          workflow_run_id: workflow_run_id,
          retry_count: retry_count
        })
      else
        elog(e)
        raise
      end
    end
  end

  def backoff_multiplier
    1.minute
  end

  def handle_retries_exhausted(context)
    if context[:last_exception].is_a?(Installations::Error) &&
        context[:last_exception].reason == :workflow_run_not_found
      run = WorkflowRun.find(context[:workflow_run_id])
      run.unavailable! if run.may_unavailable?
      elog(context[:last_exception])
    end
  end
end
