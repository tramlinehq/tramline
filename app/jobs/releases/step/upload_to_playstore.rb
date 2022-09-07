require "zip"

class Releases::Step::UploadToPlaystore < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    step = step_run.step
    package_name = step.app.bundle_identifier
    key = StringIO.new(step.deployment_provider.providable.json_key)
    release_version = step_run.train_run.release_version

    step_run.build_artifact.file.blob.open do |zip_file|
      # FIXME: This is an expensive operation, we should be unzipping the artifacts before pushing to object store
      aab_file = Zip::File.open(zip_file).glob("*.{aab,apk,txt}").first

      Tempfile.open(%w[playstore-artifact .aab]) do |tmp|
        api = Installations::Google::PlayDeveloper::Api.new(package_name, key, release_version)
        aab_file.extract(tmp.path) { true }
        api.upload(tmp)
        raise api.errors if api.errors.present?
      end
    end

    step_run.build_artifact.create_release_situation!(status: ReleaseSituation.statuses[:bundle_uploaded])
  end
end
