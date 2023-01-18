class Releases::UploadArtifact < ApplicationJob
  queue_as :high

  def perform(step_run_id, artifacts_url)
    run = Releases::Step::Run.find(step_run_id)

    begin
      run.artifacts_url = artifacts_url
      run.upload_artifact!
    rescue => e
      log(e)
      run.build_upload_failed!
    end
  end

  def log(e)
    Rails.logger.error(e)
    Sentry.capture_exception(e)
  end
end
