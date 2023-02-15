class Deployments::AppStoreConnect::TestFlightReleaseJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.app_store_integration?
    return unless run.release.on_track?

    run.release_to_testflight!
  end
end
