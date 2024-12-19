class Deployments::GoogleFirebase::UpdateUploadStatusJob
  include Sidekiq::Job
  include RetryableJob
  include Backoffable
  extend Loggable

  self.MAX_RETRIES = 5
  queue_as :high

  def compute_backoff(retry_count)
    if @last_error.is_a?(Deployments::GoogleFirebase::Release::UploadNotComplete)
      backoff_in(attempt: retry_count, period: :minutes, type: :static, factor: 2).to_i
    else
      self.class.elog(@last_error)
      raise "Retries exhausted"
    end
  end

  def perform(deployment_run_id, op_name, retry_context = {})
    @last_error = retry_context["original_exception"]&.[]("class")&.constantize

    run = DeploymentRun.find(deployment_run_id)
    return if !run.google_firebase_integration?

    begin
      Deployments::GoogleFirebase::Release.update_upload_status!(run, op_name)
    rescue => e
      @last_error = e
      retry_with_backoff(e, {
        step_run_id: deployment_run_id,
        op_name: op_name
      })
    end
  end
end
