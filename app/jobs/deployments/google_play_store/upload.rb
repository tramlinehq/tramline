class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  API = Installations::Google::PlayDeveloper::Api

  def perform(deployment_run_id)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment_run.with_lock do
      deployment = deployment_run.deployment
      return unless deployment.integration.google_play_store_integration?
      step_run = deployment_run.step_run
      upload(step_run, deployment.access_key)
      deployment_run.upload!
    end
  end

  def upload(step_run, key)
    step = step_run.step
    package_name = step.app.bundle_identifier
    release_version = step_run.train_run.release_version

    step_run.build_artifact.file_for_upload do |file|
      API.upload(package_name, key, release_version, file)
    rescue Installations::Errors::BuildExistsInBuildChannel => e
      logger.error(e)
      Sentry.capture_exception(e)
    end
  end
end
