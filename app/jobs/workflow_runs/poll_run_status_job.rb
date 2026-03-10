class WorkflowRuns::PollRunStatusJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 3

  sidekiq_retry_in do |count, _ex|
    backoff_in(attempt: count + 1, period: :seconds, type: :linear)
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?
    return unless workflow_run.started?

    WorkflowProcessors::WorkflowRunV2.process(workflow_run)
  end
end
