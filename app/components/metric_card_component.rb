class MetricCardComponent < ViewComponent::Base
  include LinkHelper
  include AssetsHelper

  attr_reader :name, :values, :provider, :external_url
  delegate :current_user, to: :helpers

  def initialize(name:, values:, provider: nil, external_url: nil)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
  end

  def metric_color(is_healthy)
    return "text-main" unless current_user.release_monitoring?
    case is_healthy
    when true
      "text-green-800 font-semibold"
    when false
      "text-red-800 font-semibold"
    else
      "text-main"
    end
  end

  def metric_title(metric)
    return unless current_user.release_monitoring?
    return "unhealthy" if metric[:is_healthy] == false
    "healthy" if metric[:is_healthy] == true
  end

  def metric_health(val)
    return unless current_user.release_monitoring?
    return if val[:is_healthy].blank?
    return if val[:is_healthy]
    inline_svg "exclamation.svg", classname: "w-5 h-5 text-red-800 ml-1"
  end

  def display_values
    values.compact.reject { |k, v| v[:value].nil? }
  end

  def grid_size
    display_values.size
  end
end
