class WorkflowRuns::UploadArtifactJob
  include Sidekiq::Job
  extend Loggable
  queue_as :high

  sidekiq_options retry: 3

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Errors::ArtifactsNotFound)
      10 * (count + 1)
    else
      elog(exception)
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    elog(ex)
    workflow_run = WorkflowRun.find(msg["args"].first)
    workflow_run.build_upload_failed!
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    return unless workflow_run.active?

    workflow_run.upload_artifact!
  end
end
