class MetricCardComponent < ViewComponent::Base
  include LinkHelper
  include AssetsHelper

  attr_reader :name, :values, :provider, :external_url

  def initialize(name:, values:, provider:, external_url:)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
  end

  def metric_color(is_healthy)
    case is_healthy
    when true
      "text-green-800"
    when false
      "text-red-800"
    else
      "test-gray-800"
    end
  end

  def metric_title(metric)
    return "unhealthy" if metric[:is_healthy] == false
    "healthy" if metric[:is_healthy] == true
  end
end
