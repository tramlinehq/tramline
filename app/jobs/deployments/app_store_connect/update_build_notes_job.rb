class Deployments::AppStoreConnect::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    Deployments::AppStoreConnect::Release.update_build_notes!(DeploymentRun.find(deployment_run_id))
  end
end
