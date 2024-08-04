class V2::TriggerSubmissionsJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    Coordinators::TriggerSubmissions.call(workflow_run)
  end
end
