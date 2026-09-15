class FetchHealthMetricsJob < ApplicationJob
  def perform(production_release_id, frequency, provider_type = nil)
    production_release = ProductionRelease.find(production_release_id)
    release = production_release.release
    return if release.stopped?
    return if production_release.stale?

    provider = resolve_provider(production_release, provider_type)
    return if provider.blank?
    return if release.finished? && production_release.beyond_monitoring_period_for?(provider)

    begin
      production_release.fetch_health_data!(provider)
    ensure
      FetchHealthMetricsJob.set(wait: frequency).perform_async(production_release_id, frequency, provider_type)
    end
  end

  private

  def resolve_provider(production_release, provider_type)
    if provider_type.present?
      klass = provider_type.safe_constantize
      return if klass.blank?
      production_release.app.monitoring_providers&.find { |p| p.instance_of?(klass) }
    else
      production_release.monitoring_provider
    end
  end
end
