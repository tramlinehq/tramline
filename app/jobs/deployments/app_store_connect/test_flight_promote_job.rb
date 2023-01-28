class Deployments::AppStoreConnect::TestFlightPromoteJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.app_store_integration?
    run.promote_to_appstore!
  end
end
