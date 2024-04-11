class MetricCardComponent < V2::BaseComponent
  TEXT_SIZE = {
    sm: "text-base",
    base: "text-xl"
  }

  def initialize(name:, values:, provider: nil, external_url: nil, size: :base)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
    @size = size
  end

  attr_reader :name, :values, :provider, :external_url, :size
  delegate :current_user, to: :helpers

  def health_defined?(val)
    current_user.release_monitoring? && !val[:is_healthy].nil?
  end

  def metric_color(is_healthy)
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
    return "unhealthy" if metric[:is_healthy] == false
    "healthy" if metric[:is_healthy] == true
  end

  def rule_for(metric)
    rule = metric[:rule]
    return unless rule
    "Healthy if #{rule.trigger_rule_expressions.map(&:to_s).join(", ")} using #{rule.name} rule"
  end

  def display_values
    values.compact.reject { |k, v| v[:value].nil? }
  end

  def grid_size
    display_values.size
  end

  def text_size
    TEXT_SIZE[@size]
  end
end
