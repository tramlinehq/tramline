class Deployments::AppStoreConnect::SubmitForAppReviewJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.app_store_integration?
    return unless run.release.on_track?
    return unless run.production_channel?

    run.prepare_for_release!
  end
end
