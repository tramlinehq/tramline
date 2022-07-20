class Releases::Step::UploadArtifact < ApplicationJob
  queue_as :high
  sidekiq_options retry: false

  delegate :transaction, to: ApplicationRecord

  def perform(step_run_id, installation_id, artifacts_url)
    step_run = step_run(step_run_id)
    stream = get_download_stream(step_run, archive_download_url(installation_id, artifacts_url))
    build_artifact = BuildArtifact.new(step_run: step_run)

    transaction do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: stream,
        filename: "step-run-#{step_run_id}-release.zip",
        content_type: "application/zip"
      )

      build_artifact.file = blob
      build_artifact.save!
    end

    if step_run.step.build_artifact_integration == "GooglePlayStoreIntegration"
      Releases::Step::UploadToPlaystore.perform_later(step_run_id)
    end
  end

  # FIXME: this is tied to github, but should be made generic eventually
  def get_download_stream(step_run, url)
    gh_api = Installations::Github::Api.new(installation_id(step_run))
    gh_api.artifact_io_stream(url)
  end

  def step_run(id)
    Releases::Step::Run.find(id)
  end

  def installation_id(step_run)
    step_run.train_run.train.ci_cd_provider.installation_id
  end

  def archive_download_url(installation_id, artifacts_url)
    Installations::Github::Api.new(installation_id).artifacts(artifacts_url).first["archive_download_url"]
  end
end
