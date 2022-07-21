require "zip"

class Releases::Step::UploadToPlaystore < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    step = step_run.step
    train = step_run.step.train
    app = train.app
    step_run.build_artifact.file.blob.open do |zip_file|
      # FIXME This is an expensive operation, we should be unzipping the artifacts before pushing to object store
      aab_file = Zip::File.open(zip_file).glob("*.{aab,apk,txt}").first
      Tempfile.open(["playstore-artifact", ".aab"]) do |tmp|
        aab_file.extract(tmp.path) { true }
        api = Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier,
          tmp,
          StringIO.new(step.deployment_provider.providable.json_key),
          step.deployment_channel)
        api.upload
        raise api.errors if api.errors.present?
      end
    end
  end
end
