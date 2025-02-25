class WorkflowRuns::TriggerJob < ApplicationJob
  queue_as :high

  TRIGGER_FAILED_REASONS = [
    :workflow_parameter_not_provided,
    :workflow_dispatch_missing
  ]

  def perform(workflow_run_id, retrigger = false)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return unless workflow_run.may_initiated?

    workflow_run.trigger!(retrigger:)
  rescue Installations::Error => err
    if err.reason.in?(TRIGGER_FAILED_REASONS)
      workflow_run.trigger_failed!(err)
    else
      raise
    end
  end
end
