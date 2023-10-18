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

  def chart_scope
    chart[:scope]
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

  def title
    chart[:title]
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
end
