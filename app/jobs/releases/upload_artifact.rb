class Releases::UploadArtifact
  include Sidekiq::Job
  include RetryableJob
  include Backoffable
  extend Loggable

  self.MAX_RETRIES = 3
  queue_as :high

  def compute_backoff(retry_count)
    if @last_error.is_a?(Installations::Error) && @last_error.reason == :artifact_not_found
      # Linear backoff: 10 * (count + 1)
      backoff_in(attempt: retry_count, period: :seconds, type: :linear, factor: 10).to_i
    else
      self.class.elog(@last_error)
      raise "Retries exhausted"
    end
  end

  def handle_retries_exhausted(context)
    self.class.elog(context[:last_exception])
    run = StepRun.find(context[:step_run_id])
    run.build_upload_failed!
    run.event_stamp!(reason: :build_unavailable, kind: :error, data: {version: run.build_version})
  end

  def perform(step_run_id, artifacts_url, retry_context = {})
    @last_error = retry_context["original_exception"]&.[]("class")&.constantize

    run = StepRun.find(step_run_id)
    return unless run.active?

    begin
      run.artifacts_url = artifacts_url
      run.upload_artifact!
      run.event_stamp!(reason: :build_available, kind: :notice, data: {version: run.build_version})
    rescue => e
      @last_error = e
      retry_with_backoff(e, retry_context.merge(step_run_id:))
      raise e
    end
  end
end
