class V2::CreateBuildJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)

    Coordinators::CreateBuild.call(workflow_run)
  end
end
