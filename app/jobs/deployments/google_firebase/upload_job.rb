class Deployments::GoogleFirebase::UploadJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.google_firebase_integration?

    Deployments::GoogleFirebase::Release.upload!(run)
  end
end
