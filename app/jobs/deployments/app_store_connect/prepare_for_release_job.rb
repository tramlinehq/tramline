class Deployments::AppStoreConnect::PrepareForReleaseJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    Deployments::AppStoreConnect::Release.prepare_for_release!(DeploymentRun.find(deployment_run_id))
  end
end
