class V2::CreateBuildJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(workflow_run_id, pre_prod_release_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    pre_prod_release = PreProdRelease.find(pre_prod_release_id)

    Coordinators::CreateBuild.call(workflow_run, pre_prod_release)
  end
end
