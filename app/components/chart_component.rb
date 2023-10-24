class ChartComponent < ViewComponent::Base
  include AssetsHelper
  using RefinedHash
  CHART_TYPES = %w[area line donut stacked-bar]
  InvalidChartType = Class.new(StandardError)

  def initialize(chart, icon:)
    @chart = chart
    @icon = icon
    raise InvalidChartType unless chart[:type].in?(CHART_TYPES)
  end

  attr_reader :chart

  def type
    @type ||= chart[:type]
  end

  def value_format
    chart[:value_format]
  end

  def series
    ungroup_series.to_json
  end

  def series_raw
    chart[:data]
  end

  def title
    I18n.t("charts.#{chart[:name]}.title")
  end

  def chart_scope
    I18n.t("charts.#{chart[:name]}.scope")
  end

  def corner_icon
    inline_svg(@icon, classname: "w-6 fill-current shrink-0")
  end

  def help_icon
    inline_svg("question_mark.svg", classname: "w-4 inline-flex fill-current shrink-0 text-gray-400")
  end

  def subgroup? = chart[:subgroup]

  def stacked? = chart[:stacked]

  def line? = chart[:type] == "line"

  def area? = chart[:type] == "area"

  def donut? = chart[:type] == "donut"

  def stacked_bar? = chart[:type] == "stacked-bar"

  # {"8.0.2"=>{"android"=>1, "ios"=>0}}
  # Input:
  # {
  #   "8.0.1": {
  #     "android": {
  #       "QA Android Review": 2,
  #       "Android Release": 4
  #     },
  #     "ios": {
  #       "QA iOS Review": 6,
  #       "iOS Release": 8
  #     }
  #   },
  #   "8.0.2": {
  #     "android": {
  #       "QA Android Review": 3,
  #       "Android Release": 5
  #     },
  #     "ios": {
  #       "QA iOS Review": 7,
  #       "iOS Release": 9
  #     }
  #   }
  # }
  #
  # Output:
  # [{:name=>"QA Android Review", :group=>"android", :data=>{"8.0.1"=>2, "8.0.2"=>3}},
  #  {:name=>"Android Release", :group=>"android", :data=>{"8.0.1"=>4, "8.0.2"=>5}},
  #  {:name=>"QA iOS Review", :group=>"ios", :data=>{"8.0.1"=>6, "8.0.2"=>7}},
  #  {:name=>"iOS Release", :group=>"ios", :data=>{"8.0.1"=>8, "8.0.2"=>9}}]
  def ungroup_series(input = series_raw)
    input.each_with_object([]) do |(category, grouped_maps), result|
      grouped_maps.each do |group, inner_data|
        if inner_data.is_a?(Hash) && stacked?
          inner_data.each do |name, value|
            item = result.find { |r| r[:name] == name && r[:group] == group }
            item ||= {name: name, group: group, data: {}}
            item[:data][category] = value
            result.push(item) unless result.include?(item)
          end
        else
          item = result.find { |r| r[:name] == group }
          item ||= {name: group, data: {}}
          item[:data][category] = inner_data
          result.push(item) unless result.include?(item)
        end
      end
    end.then { cartesian_series(_1) }
  end

  def cartesian_series(input = series_raw)
    input.map do |series|
      series.update_key(:data) do |data|
        data.map do |x, y|
          {x: x, y: y}
        end
      end
    end
  end
end
