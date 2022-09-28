class Releases::Step::UploadArtifact < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0

  def perform(step_run_id, installation_id, artifacts_url)
    step_run = Releases::Step::Run.find(step_run_id)

    begin
      stream = get_download_stream(step_run, archive_download_url(installation_id, artifacts_url))
      BuildArtifact.new(step_run: step_run).save_zip!(stream)
      Triggers::Deployment.call(step_run: step_run)
    rescue => e
      Rails.logger.error e
      Sentry.capture_exception(e)
      step_run.fail_deploy! # FIXME: this should actually be upload_failed maybe?
    end
  end

  # FIXME: this is tied to github, but should be made generic eventually
  def get_download_stream(step_run, url)
    Installations::Github::Api.new(installation_id(step_run)).artifact_io_stream(url)
  end

  def installation_id(step_run)
    step_run.train_run.train.ci_cd_provider.installation_id
  end

  VERSION_ARTIFACT_NAME = "version"

  # FIXME: this is tied to github, but should be made generic eventually
  def archive_download_url(installation_id, artifacts_url)
    Installations::Github::Api
      .new(installation_id)
      .artifacts(artifacts_url)
      .reject { |artifact| artifact["name"] == VERSION_ARTIFACT_NAME }
      .first["archive_download_url"]
  end
end
