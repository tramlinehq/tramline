class Releases::UploadArtifact
  include Sidekiq::Job
  extend Loggable
  queue_as :high

  sidekiq_options retry: 3

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Installations::Error) && exception && exception.reason == :artifact_not_found
      10 * (count + 1)
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    elog(ex)
    run = StepRun.find(msg["args"].first)
    run.build_upload_failed!
    run.event_stamp!(reason: :build_unavailable, kind: :error, data: {version: run.build_version})
  end

  def perform(step_run_id, artifacts_url)
    run = StepRun.find(step_run_id)
    return unless run.active?

    run.artifacts_url = artifacts_url
    run.upload_artifact!
    run.event_stamp!(reason: :build_available, kind: :notice, data: {version: run.build_version})
  end
end
