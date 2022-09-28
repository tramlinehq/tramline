require "zip"

class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  def perform(deployment_run_id)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment = deployment_run.deployment
    return unless deployment.integration.google_play_store_integration?

    step_run = deployment_run.step_run
    upload(step_run, deployment.access_key)
    deployment_run.upload!
  end

  def upload(step_run, key)
    step = step_run.step
    package_name = step.app.bundle_identifier
    release_version = step_run.train_run.release_version

    step_run.build_artifact.file.blob.open do |zip_file|
      # FIXME: This is an expensive operation, we should not be unzipping here but before pushing to object store
      aab_file = Zip::File.open(zip_file).glob("*.{aab,apk,txt}").first

      Tempfile.open(%w[playstore-artifact .aab]) do |tmp|
        api = Installations::Google::PlayDeveloper::Api.new(package_name, key, release_version)
        aab_file.extract(tmp.path) { true }
        api.upload(tmp)
        raise api.errors if api.errors.present?
      end
    end
  end
end
