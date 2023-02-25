class Deployments::ReleaseJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    DeploymentRun.find(deployment_run_id).kickoff_release_on_play_store!
  end
end
