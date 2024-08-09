class V2::FetchHealthMetricsJob < ApplicationJob
  queue_as :high
  RE_ENQUEUE_INTERVAL = 5.minutes

  def perform(production_release_id)
    ProductionRelease.find(production_release_id).fetch_health_data!
  ensure
    V2::FetchHealthMetricsJob.set(wait: RE_ENQUEUE_INTERVAL).perform_later(production_release_id)
  end
end
