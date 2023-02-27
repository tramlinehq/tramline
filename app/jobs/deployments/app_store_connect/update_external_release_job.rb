class Deployments::AppStoreConnect::UpdateExternalReleaseJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(deployment_run_id, attempt: 1)
    release = Deployments::AppStoreConnect::Release.new(DeploymentRun.find(deployment_run_id))
    return if release.update_external_release.ok?
    release.locate_external_release(attempt: attempt.succ, wait: backoff_in_minutes(attempt))
  end
end
