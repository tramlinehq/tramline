class Releases::FetchHealthMetricsJob < ApplicationJob
  queue_as :high

  RELEASE_MONITORING_PERIOD_IN_DAYS = 15

  def perform(deployment_run_id, frequency)
    run = DeploymentRun.find(deployment_run_id)
    return if run.release.stopped?
    return if run.release.finished? && run.release.completed_at < RELEASE_MONITORING_PERIOD_IN_DAYS.days.ago

    begin
      run.fetch_health_data!
    ensure
      Releases::FetchHealthMetricsJob.set(wait: frequency).perform_async(deployment_run_id, frequency)
    end
  end
end
