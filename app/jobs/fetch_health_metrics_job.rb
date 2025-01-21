class FetchHealthMetricsJob < ApplicationJob
  queue_as :high

  def perform(production_release_id, frequency)
    production_release = ProductionRelease.find(production_release_id)
    release = production_release.release
    return if release.stopped?
    return if release.finished? && production_release.beyond_monitoring_period?
    return if production_release.stale?

    begin
      production_release.fetch_health_data!
    ensure
      FetchHealthMetricsJob.set(wait: frequency).perform_later(production_release_id, frequency)
    end
  end
end
