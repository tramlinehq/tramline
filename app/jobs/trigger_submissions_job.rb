class TriggerSubmissionsJob < ApplicationJob
  MAX_RETRIES = 3
  queue_as :high

  # TODO: move to sidekiq retry
  def perform(workflow_run_id, retry_count = 0)
    workflow_run = WorkflowRun.find(workflow_run_id)
    Coordinators::TriggerSubmissions.call(workflow_run)
  rescue Installations::Error
    if retry_count >= MAX_RETRIES
      workflow_run&.triggering_release&.fail!
    else
      retry_count += 1
      next_run_time = retry_count * 300.seconds
      Rails.logger.debug { "Failed to fetch build artifact for workflow run #{workflow_run_id}, retrying in #{next_run_time} seconds" }
      TriggerSubmissionsJob.perform_in(next_run_time, workflow_run_id, retry_count)
    end
  rescue => ex
    elog(ex, level: :warn)
    workflow_run&.triggering_release&.fail!
  end
end
