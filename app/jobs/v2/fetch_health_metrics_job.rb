class V2::FetchHealthMetricsJob < ApplicationJob
  queue_as :high
  RE_ENQUEUE_INTERVAL = 5.minutes

  def perform(production_release_id)
    production_release = ProductionRelease.find(production_release_id)
    release = production_release.release
    return if release.stopped?
    return if release.finished? && production_release.beyond_monitoring_period?

    begin
      production_release.fetch_health_data!
    ensure
      V2::FetchHealthMetricsJob.set(wait: RE_ENQUEUE_INTERVAL).perform_later(production_release_id)
    end
  end
end
