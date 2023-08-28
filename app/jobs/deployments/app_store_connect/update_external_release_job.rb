class Deployments::AppStoreConnect::UpdateExternalReleaseJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 100

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)
      backoff_in(attempt: count, period: :minutes, type: :linear, factor: 5).to_i
    else
      elog(ex)
      :kill
    end
  end

  def perform(deployment_run_id)
    Deployments::AppStoreConnect::Release.update_external_release(DeploymentRun.find(deployment_run_id))
  end
end
