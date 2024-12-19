class Deployments::AppStoreConnect::PrepareForReleaseJob
  include Sidekiq::Job
  include RetryableJob

  self.MAX_RETRIES = 3
  queue_as :high

  def compute_backoff(retry_count)
    ex = @last_exception
    if ex.is_a?(Deployments::AppStoreConnect::Release::PreparedVersionNotFoundError)
      1.minute.to_i
    else
      super
    end
  end

  def perform(deployment_run_id, force = false, retry_args = {})
    @last_exception = retry_args.is_a?(Hash) ? retry_args[:last_exception] : nil

    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    run = DeploymentRun.find(deployment_run_id)

    begin
      Deployments::AppStoreConnect::Release.prepare_for_release!(run, force: force)
    rescue Deployments::AppStoreConnect::Release::PreparedVersionNotFoundError => e
      retry_with_backoff(e, {deployment_run_id: deployment_run_id, retry_count: retry_count})
      raise e
    end
  end

  def on_retries_exhausted(context)
    run = DeploymentRun.find(context[:deployment_run_id])
    run.fail_with_error(context[:last_exception])
  end
end
