class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0

  API = Installations::Google::PlayDeveloper::Api

  def perform(deployment_run_id)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment_run.with_lock do
      deployment = deployment_run.deployment
      return unless deployment.integration.google_play_store_integration?
      step_run = deployment_run.step_run
      upload(deployment_run, step_run, deployment.access_key)
    end
  end

  def upload(deployment_run, step_run, key)
    step = step_run.step
    package_name = step.app.bundle_identifier
    release_version = step_run.train_run.release_version

    step_run.build_artifact.file_for_playstore_upload do |file|
      API.upload(package_name, key, release_version, file)
    rescue Installations::Errors::BuildExistsInBuildChannel, Installations::Errors::DuplicatedBuildUploadAttempt => e
      # FIXME: this is a hack because it's possible to send to play store in parallel
      # this should be fixed as a design, maybe call deployments sequentially
      deployment_run.event_stamp!(reason: :duplicate_build, kind: :error)
      log(e)
    rescue Installations::Errors::BundleIdentifierNotFound => e
      log(e)
      deployment_run.event_stamp!(reason: :bundle_identifier_not_found, kind: :error)
      return deployment_run.dispatch_fail!
    end

    deployment_run.upload!
  end

  def log(e)
    logger.error(e)
    Sentry.capture_exception(e)
  end
end
