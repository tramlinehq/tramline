class Deployments::AppStoreConnect::FindLiveReleaseJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 14

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)
      backoff_in(count, :minutes).seconds
    else
      elog(ex)
      :kill
    end
  end

  def perform(deployment_run_id)
    Deployments::AppStoreConnect::Release.track_live_release_status(DeploymentRun.find(deployment_run_id))
  end
end
