class TriggerSubmissionsJob < ApplicationJob
  MAX_RETRIES = 3
  include Loggable
  queue_as :high

  def perform(workflow_run_id, retry_count = 0)
    workflow_run = WorkflowRun.find(workflow_run_id)
    Coordinators::TriggerSubmissions.call(workflow_run)
  rescue Installations::Error => ex
    raise unless ex.reason == :artifact_not_found
    if retry_count >= MAX_RETRIES
      elog(ex)
      workflow_run&.triggering_release&.fail!
    else
      Rails.logger.debug { "Failed to fetch build artifact for workflow run #{workflow_run_id}, retrying in 30 seconds" }
      TriggerSubmissionsJob
        .set(wait_time: retry_count * 10.seconds)
        .perform_later(workflow_run_id, retry_count + 1)
    end
  rescue => ex
    elog(ex)
    workflow_run&.triggering_release&.fail!
  end
end
