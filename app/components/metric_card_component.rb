class MetricCardComponent < ViewComponent::Base
  include LinkHelper
  include AssetsHelper

  attr_reader :name, :values, :provider, :external_url
  delegate :current_user, to: :helpers

  def initialize(name:, values:, provider:, external_url:)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
  end

  def metric_color(is_healthy)
    return "test-gray-800" unless current_user.release_monitoring?
    case is_healthy
    when true
      "text-green-800 font-semibold"
    when false
      "text-red-800 font-semibold"
    else
      "test-gray-800"
    end
  end

  def metric_title(metric)
    return unless current_user.release_monitoring?
    return "unhealthy" if metric[:is_healthy] == false
    "healthy" if metric[:is_healthy] == true
  end
end
