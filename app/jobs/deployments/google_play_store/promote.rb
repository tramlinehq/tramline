class Deployments::GooglePlayStore::Promote < ApplicationJob
  queue_as :high

  def perform(deployment_run_id, rollout_percentage)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment_run.with_lock do
      return unless deployment_run.promotable?
      deployment = deployment_run.deployment
      return unless deployment.integration.google_play_store_integration?
      step_run = deployment_run.step_run
      step = step_run.step
      package_name = step.app.bundle_identifier
      release_version = step_run.train_run.release_version
      api = Installations::Google::PlayDeveloper::Api.new(package_name, deployment.access_key, release_version)
      api.promote(step.deployment_channel, step_run.build_number, rollout_percentage)
      raise api.errors if api.errors.present?
      deployment_run.release!
    end
  end
end
