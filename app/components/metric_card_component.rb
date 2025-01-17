class MetricCardComponent < BaseComponent
  def initialize(name:, values:, provider: nil, external_url: nil, size: nil)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
    @size = size
  end

  attr_reader :name, :values, :provider, :external_url, :size
  delegate :current_user, to: :helpers

  def health_defined?(val)
    !val[:is_healthy].nil?
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

  def rules_for(metric)
    metric[:rules]
  end

  def rule_description(rule)
    content_tag(:div, class: "flex flex-col items-start text-xs") do
      concat content_tag(:span, "Unhealthy if #{rule.trigger_rule_expressions.map(&:to_s).join(", ")}")
      concat content_tag(:span, "When #{rule.filter_rule_expressions.map(&:to_s).join(" & ")}")
      concat content_tag(:span, "Using #{rule.name} rule")
    end
  end

  def display_values
    values.compact.reject { |k, v| v[:value].nil? }
  end

  def grid_size
    display_values.size
  end
end
