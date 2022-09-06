class Releases::Step::UploadArtifact < ApplicationJob
  queue_as :high
  sidekiq_options retry: false
  delegate :transaction, to: ApplicationRecord

  VERSION_ARTIFACT_NAME = "version"

  class BadBuildArtifactIntegration < StandardError; end

  def perform(step_run_id, installation_id, artifacts_url, should_auto_deploy: false)
    step_run = Releases::Step::Run.find(step_run_id)
    stream = get_download_stream(step_run, archive_download_url(installation_id, artifacts_url))
    BuildArtifact.new(step_run: step_run).save_zip!(stream)

    case step_run.step.build_artifact_integration
    when "GooglePlayStoreIntegration"
      Releases::Step::UploadToPlaystore.perform_later(step_run_id, should_auto_deploy)
    when "SlackIntegration"
      Releases::Step::DeploymentFinished.perform_later(step_run_id, should_auto_deploy)
    else
      raise BadBuildArtifactIntegration, "This BuildArtifact Integration is unsupported!"
    end
  end

  # FIXME: this is tied to github, but should be made generic eventually
  def get_download_stream(step_run, url)
    Installations::Github::Api.new(installation_id(step_run)).artifact_io_stream(url)
  end

  def installation_id(step_run)
    step_run.train_run.train.ci_cd_provider.installation_id
  end

  def archive_download_url(installation_id, artifacts_url)
    Installations::Github::Api
      .new(installation_id)
      .artifacts(artifacts_url)
      .reject { |artifact| artifact["name"] == VERSION_ARTIFACT_NAME }
      .first["archive_download_url"]
  end
end
