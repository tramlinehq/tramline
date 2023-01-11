class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high

  API = Installations::Google::PlayDeveloper::Api

  def perform(deployment_run_id)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment = deployment_run.deployment
    return unless deployment.integration.google_play_store_integration?
    step_run = deployment_run.step_run
    deployment_run.with_lock { upload(deployment_run, step_run, deployment.access_key) }
  end

  # FIXME: this is a hack because it's possible to send to play store in parallel
  # this should be fixed as a design, maybe call deployments sequentially
  def upload(deployment_run, step_run, key)
    step = step_run.step
    package_name = step.app.bundle_identifier
    release_version = step_run.train_run.release_version

    # TODO: Clean this crap up
    step_run.build_artifact.file_for_playstore_upload do |file|
      API.upload(package_name, key, release_version, file)
    rescue Installations::Errors::BuildExistsInBuildChannel, Installations::Errors::DuplicatedBuildUploadAttempt => e
      deployment_run.event_stamp!(reason: :duplicate_build, kind: :error)
      log(e)
    rescue Installations::Errors::BundleIdentifierNotFound => e
      log(e)
      deployment_run.event_stamp!(reason: :bundle_identifier_not_found, kind: :error)
      return deployment_run.upload_fail!
    rescue Installations::Errors::GooglePlayDeveloperAPIInvalidPackage => e
      log(e)
      deployment_run.event_stamp!(reason: :invalid_package, kind: :error)
      return deployment_run.upload_fail!
    rescue Installations::Errors::GooglePlayDeveloperAPIAPKsAreNotAllowed => e
      log(e)
      deployment_run.event_stamp!(reason: :apks_are_not_allowed, kind: :error)
      return deployment_run.upload_fail!
    end

    deployment_run.upload!
  end

  def log(e)
    logger.error(e)
    Sentry.capture_exception(e)
  end
end
