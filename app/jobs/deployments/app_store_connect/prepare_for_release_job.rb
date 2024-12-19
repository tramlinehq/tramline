class Deployments::AppStoreConnect::PrepareForReleaseJob < ApplicationJob
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 3

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Deployments::AppStoreConnect::Release::PreparedVersionNotFoundError)
      backoff_in(attempt: count, period: :minutes, type: :static, factor: 1).to_i
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    run = DeploymentRun.find(msg["args"].first)
    run.fail_with_error(ex)
  end

  def perform(deployment_run_id, force = false)
    run = DeploymentRun.find(deployment_run_id)
    Deployments::AppStoreConnect::Release.prepare_for_release!(run, force:)
  end
end
