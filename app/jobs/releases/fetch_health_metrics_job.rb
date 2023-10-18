class Releases::FetchHealthMetricsJob < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(id: deployment_run_id)
    return if run.release.finished?

    run.fetch_health_data!
    Releases::FetchHealthMetricsJob.set(wait: 5.minutes).perform_later(deployment_run_id)
  end
end
