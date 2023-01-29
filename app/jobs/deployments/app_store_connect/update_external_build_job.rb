class Deployments::AppStoreConnect::UpdateExternalBuildJob < ApplicationJob
  include Loggable
  queue_as :high

  AttemptMustBeGreaterThanZero = Class.new(StandardError)

  def perform(deployment_run_id, attempt:)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.app_store_integration?

    unless run.update_external_build.ok?
      run.locate_external_build(attempt: attempt.succ, wait: backoff(attempt))
    end
  end

  def backoff(attempt = 1)
    raise AttemptMustBeGreaterThanZero if attempt.zero?
    (10 * (attempt**2)).to_i.minutes
  end
end
