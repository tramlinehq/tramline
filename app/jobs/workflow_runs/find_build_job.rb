class WorkflowRuns::FindBuildJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 8

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :build_not_found
      backoff_in(attempt: count, period: :minutes).to_i
    else
      elog(ex)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :build_not_found
      workflow_run = WorkflowRun.find(msg["args"].first)
      workflow_run.build_not_found!
    end
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?

    workflow_run.find_build.value!
    workflow_run.build_found!
  end
end
