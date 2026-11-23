class WorkflowRuns::TriggerJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 25

  RETRYABLE_TRIGGER_FAILURE_REASONS = [
    :workflow_run_not_runnable,
    :generic_client_error
  ]

  sidekiq_retry_in do |count, ex, msg|
    if retryable_trigger_failure?(ex)
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 2).to_i
    else
      mark_failed!(msg, ex)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if retryable_trigger_failure?(ex)
      mark_failed!(msg, ex)
    end
  end

  def perform(workflow_run_id, retrigger = false)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return unless workflow_run.may_initiated?
    workflow_run.trigger!(retrigger:)
  rescue WorkflowRun::ExternalUniqueNumberNotFound
    workflow_run.unavailable!
  end

  def self.mark_failed!(msg, ex)
    run = WorkflowRun.find(msg["args"].first)
    run.trigger_failed!(ex) if run.may_trigger_failed?
  end

  def self.retryable_trigger_failure?(ex)
    ex.is_a?(Installations::Error) && RETRYABLE_TRIGGER_FAILURE_REASONS.include?(ex.reason)
  end
end
