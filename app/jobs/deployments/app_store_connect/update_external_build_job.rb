class Deployments::AppStoreConnect::UpdateExternalBuildJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.app_store_integration?

    run.find_and_update_external_build!
  end
end
