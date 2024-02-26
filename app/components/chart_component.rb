class ChartComponent < ViewComponent::Base
  include AssetsHelper
  using RefinedHash
  CHART_TYPES = %w[area line stacked-bar polar-area]
  InvalidChartType = Class.new(StandardError)
  CHART_COLORS = %w[#1A56DB #9061F9 #E74694 #31C48D #FDBA8C #16BDCA #7E3BF2 #1C64F2 #F05252]

  def initialize(chart, icon:)
    raise InvalidChartType if chart && !chart[:type].in?(CHART_TYPES)

    @icon = icon
    @chart = chart
    @chart = {} if chart.blank?
  end

  attr_reader :chart

  def type
    @type ||= chart[:type]
  end

  def value_format
    chart[:value_format]
  end

  def show_x_axis
    return true if chart[:show_x_axis].nil?
    chart[:show_x_axis]
  end

  def show_y_axis
    return false if chart[:show_y_axis].nil?
    chart[:show_y_axis]
  end

  def series
    ungroup_series(group_colors: colors).to_json
  end

  # input:
  # {"team-a": 1,
  #  "team-b": 10}
  # group-colors:
  # {"team-a": "#145688",
  #  "team-b": "#145680"}
  # output:
  # { data: [1, 10],
  #   labels: ["team-a", "team-b"],
  #   colors: ["#145688", "#145680"] }

  def linear_series(input = series_raw)
    res = input.each_with_object({labels: [], data: [], colors: []}) do |(category, data), result|
      result[:labels] << category.to_s
      result[:data] << data
      result[:colors] << colors[category]
    end
    res[:colors] = CHART_COLORS if colors.empty?
    [res].to_json
  end

  def series_raw
    chart[:data]
  end

  def colors
    chart[:colors] || {}
  end

  def title
    chart[:title] || I18n.t("charts.#{chart[:name]}.title")
  end

  def chart_scope
    chart[:scope] || I18n.t("charts.#{chart[:name]}.scope")
  end

  def help_text
    chart[:help_text] || I18n.t("charts.#{chart[:name]}.help_text")
  end

  def corner_icon
    icon = V2::IconComponent.new("v2/info.svg", size: :md, classes: "text-main-500")
    icon.with_tooltip(help_text, placement: "top")
    icon
  end

  def subgroup? = chart[:subgroup]

  def stacked? = chart[:stacked]

  def line? = chart[:type] == "line"

  def area? = chart[:type] == "area"

  def stacked_bar? = chart[:type] == "stacked-bar"

  def polar_area? = chart[:type] == "polar-area"

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
  def ungroup_series(input = series_raw, group_colors: colors)
    input.each_with_object([]) do |(category, grouped_maps), result|
      grouped_maps.each do |group, inner_data|
        if inner_data.is_a?(Hash) && stacked?
          inner_data.each do |name, value|
            color = group_colors[group] || CHART_COLORS[result.size % CHART_COLORS.length]
            grouped_name = "#{name} (#{group})"
            item = result.find { |r| r[:name] == grouped_name && r[:group] == group }
            item ||= {name: grouped_name, group: group, data: {}, color:}
            item[:data][category] = value
            result.push(item) unless result.include?(item)
          end
        else
          color = group_colors[group] || CHART_COLORS[result.size % CHART_COLORS.length]
          item = result.find { |r| r[:name] == group }
          item ||= {name: group, data: {}, color:}
          item[:data][category] = inner_data
          result.push(item) unless result.include?(item)
        end
      end
    end.then { cartesian_series(_1) }
  end

  def cartesian_series(input = series_raw)
    x_values = input.flat_map { |item| item[:data].keys }.uniq
    input.map do |series|
      series.update_key(:data) do |data|
        x_values.map do |x|
          y = data[x] || 0
          {x:, y:}
        end
      end
    end
  end
end
