class Deployments::AppStoreConnect::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.test_flight_release?

    Deployments::AppStoreConnect::Release.update_build_notes!(run)
  end
end
