class Deployments::AppStoreConnect::FindLiveReleaseJob
  include Sidekiq::Job
  include RetryableJob
  include Backoffable
  extend Loggable

  self.MAX_RETRIES = 6000

  queue_as :high

  def compute_backoff(retry_count)
    if @last_error.is_a?(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)
      backoff_in(attempt: retry_count, period: :minutes, type: :static, factor: 5).to_i
    else
      self.class.elog(@last_error)
      raise "Retries exhausted"
    end
  end

  def perform(deployment_run_id, retry_context = {})
    @last_error = retry_context["original_exception"]&.[]("class")&.constantize

    begin
      Deployments::AppStoreConnect::Release.track_live_release_status(
        DeploymentRun.find(deployment_run_id)
      )
    rescue Deployments::AppStoreConnect::Release::ReleaseNotFullyLive => e
      @last_error = e
      retry_with_backoff(e, retry_context.merge(step_run_id: deployment_run_id))
      raise e
    rescue => e
      @last_error = e
      retry_with_backoff(e, retry_context.merge(step_run_id: deployment_run_id))
    end
  end
end
