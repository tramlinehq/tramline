class Deployments::AppStoreConnect::TestFlightReleaseJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    Deployments::AppStoreConnect::Release.to_test_flight!(DeploymentRun.find(deployment_run_id))
  end
end
