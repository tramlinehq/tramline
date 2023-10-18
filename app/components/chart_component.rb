class ChartComponent < ViewComponent::Base
  include AssetsHelper
  CHART_TYPES = %w[area line donut stacked-bar]
  InvalidChartType = Class.new(StandardError)

  def initialize(chart)
    @chart = chart
    raise InvalidChartType unless chart[:type].in?(CHART_TYPES)
  end

  attr_reader :chart

  def area?
    type == "area"
  end

  def line?
    type == "line"
  end

  def stacked_bar?
    type == "stacked-bar"
  end

  def type
    @type ||= chart[:type]
  end

  def legends
    chart[:legends].to_json
  end

  def series
    chart[:series].to_json
  end

  def categories
    chart[:x_axis].to_json
  end

  def value_format
    chart[:value_format]
  end

  def title
    I18n.t("charts.#{chart[:name]}.title")
  end

  def chart_scope
    I18n.t("charts.#{chart[:name]}.scope")
  end
end
