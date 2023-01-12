class Deployments::GooglePlayStore::Upload < ApplicationJob
  queue_as :high

  API = Installations::Google::PlayDeveloper::Api

  ALLOWED_EXCEPTIONS = {
    Installations::Errors::BuildExistsInBuildChannel => :duplicate_build,
    Installations::Errors::DuplicatedBuildUploadAttempt => :duplicate_build
  }

  DISALLOWED_EXCEPTIONS = {
    Installations::Errors::BundleIdentifierNotFound => :bundle_identifier_not_found,
    Installations::Errors::GooglePlayDeveloperAPIInvalidPackage => :invalid_package,
    Installations::Errors::GooglePlayDeveloperAPIAPKsAreNotAllowed => :apks_are_not_allowed
  }

  def perform(deployment_run_id)
    @deployment_run = DeploymentRun.find(deployment_run_id)
    @step_run = @deployment_run.step_run
    @deployment = @deployment_run.deployment

    return unless @deployment.integration.google_play_store_integration?

    @deployment_run.with_lock do
      @step_run.build_artifact.file_for_playstore_upload do |file|
        API.upload(package_name, access_key, release_version, file)
        @deployment_run.upload!
      rescue *ALLOWED_EXCEPTIONS.keys => e
        proceed!(e)
      rescue *DISALLOWED_EXCEPTIONS.keys => e
        halt!(e)
      end
    end
  end

  private

  def proceed!(exception)
    log_and_stamp(exception, ALLOWED_EXCEPTIONS[exception.class])
    @deployment_run.upload!
  end

  def halt!(exception)
    log_and_stamp(exception, DISALLOWED_EXCEPTIONS[exception.class])
    @deployment_run.upload_fail!
  end

  def log_and_stamp(exception, reason)
    log(exception)
    @deployment_run.event_stamp!(reason:, kind: :error)
  end

  def log(e)
    logger.error(e)
    Sentry.capture_exception(e)
  end

  def access_key
    @deployment.access_key
  end

  def package_name
    @step_run.step.app.bundle_identifier
  end

  def release_version
    @step_run.train_run.release_version
  end
end
