class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.google_play_store_integration?
    run.with_lock { run.upload_to_playstore! }
  end
end
