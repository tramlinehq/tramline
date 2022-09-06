require "zip"

class Releases::Step::UploadToPlaystore < ApplicationJob
  queue_as :high
  delegate :transaction, to: ApplicationRecord

  def perform(step_run_id, should_promote = true)
    step_run = Releases::Step::Run.find(step_run_id)
    step = step_run.step
    train = step_run.step.train
    app = train.app

    transaction do
      step_run.build_artifact.file.blob.open do |zip_file|
        # FIXME: This is an expensive operation, we should be unzipping the artifacts before pushing to object store
        aab_file = Zip::File.open(zip_file).glob("*.{aab,apk,txt}").first

        Tempfile.open(%w[playstore-artifact .aab]) do |tmp|
          aab_file.extract(tmp.path) { true }
          api = Installations::Google::PlayDeveloper::Api.new(
            app.bundle_identifier,
            tmp,
            StringIO.new(step.deployment_provider.providable.json_key),
            step.deployment_channel,
            step_run.train_run.release_version,
            should_promote: should_promote
          )

          api.upload

          raise api.errors if api.errors.present?
        end
      end

      status =
        if should_promote
          step_run.mark_success!
          ReleaseSituation.statuses[:released]
        else
          ReleaseSituation.statuses[:bundle_uploaded]
        end

      step_run.build_artifact.create_release_situation!(status:)
    end
  end
end
