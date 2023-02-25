class Deployments::AppStoreConnect::UpdateExternalBuildJob < ApplicationJob
  include Loggable
  queue_as :high

  AttemptMustBeGreaterThanZero = Class.new(StandardError)

  def perform(deployment_run_id, attempt: 1)
    release = Deployments::AppStoreConnect::Release.new(DeploymentRun.find(deployment_run_id))
    return if release.update_external_build.ok?

    release.locate_external_build(attempt: attempt.succ, wait: backoff(attempt))
  end

  # goes like: 10, 40, 90, 160, 250...
  def backoff(attempt = 1)
    raise AttemptMustBeGreaterThanZero if attempt.zero?
    (10 * (attempt**2)).to_i.minutes
  end
end
