require "zip"

class Releases::Step::UploadToPlaystore < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    train = step_run.step.train
    app = train.app
    step_run.build_artifact.file.blob.open do |zip_file|
      aab_file = Zip::File.open(zip_file).glob("*.{aab,apk,txt}").first
      Tempfile.open(["playstore-artififact", ".aab"]) do |tmp|
        aab_file.extract(tmp.path) { true }
        api = Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier,
          tmp,
          StringIO.new(app.integrations.build_channel_provider.json_key),
          "internal")
        api.upload
      end
    end
  end
end
