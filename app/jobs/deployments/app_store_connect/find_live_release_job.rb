class Deployments::AppStoreConnect::FindLiveReleaseJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(deployment_run_id, attempt: 1)
    release = Deployments::AppStoreConnect::Release.new(DeploymentRun.find(deployment_run_id))
    release.track_live_release_status(attempt: attempt.succ, wait: backoff_in_minutes(attempt))
  end
end
