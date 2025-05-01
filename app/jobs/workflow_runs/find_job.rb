class WorkflowRuns::FindJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 25

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Error) && exception.reason == :workflow_run_not_found
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 2).to_i
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Installations::Error) && ex.reason == :workflow_run_not_found
      run = WorkflowRun.find(msg["args"].first)
      run.unavailable! if run.may_unavailable?
    end
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    workflow_run.find_and_update_external
    workflow_run.found! if workflow_run.may_found?
  rescue WorkflowRun::ExternalUniqueNumberNotFound
    workflow_run.unavailable!
  end
end
