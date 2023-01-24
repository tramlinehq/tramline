class Releases::UploadArtifact < ApplicationJob
  include Loggable
  queue_as :high

  def perform(step_run_id, artifacts_url)
    run = Releases::Step::Run.find(step_run_id)

    begin
      run.artifacts_url = artifacts_url
      run.upload_artifact!
      run.event_stamp!(reason: :build_available, kind: :notice, data: {version: run.build_version})
    rescue => e
      elog(e)
      run.build_upload_failed!
      run.event_stamp!(reason: :build_unavailable, kind: :error, data: {version: run.build_version})
    end
  end
end
