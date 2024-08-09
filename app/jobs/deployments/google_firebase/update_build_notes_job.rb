class Deployments::GoogleFirebase::UpdateBuildNotesJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id, release_name)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.send_notes?
    return unless run.google_firebase_integration?

    Deployments::GoogleFirebase::Release.update_build_notes!(run, release_name)
  end
end
