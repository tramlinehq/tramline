class ChartComponent < V2::BaseComponent
  using RefinedHash
  CHART_TYPES = %w[area line stacked-bar polar-area]
  InvalidChartType = Class.new(StandardError)
  CHART_COLORS = %w[#1A56DB #9061F9 #E74694 #31C48D #FDBA8C #16BDCA #7E3BF2 #1C64F2 #F05252]

  def initialize(chart)
    raise InvalidChartType if chart && !chart[:type].in?(CHART_TYPES)

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

  def insufficient?
    series_raw.blank? || series_raw.keys.size < 1
  end

  def height
    chart[:height] || "110%"
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

  def annotations
    {yaxis: y_annotations}.to_json
  end

  def help_text
    chart[:help_text] || I18n.t("charts.#{chart[:name]}.help_text")
  end

  def help_link
    I18n.t("charts.#{chart[:name]}.help_link") if I18n.exists?("charts.#{chart[:name]}.help_link")
  end

  def corner_icon
    if help_text.present?
      icon = V2::IconComponent.new("info.svg", size: :md, classes: "text-secondary")
      icon.with_tooltip(help_text, placement: "top", type: :detailed) do |tooltip|
        tooltip.with_detailed_text do
          content_tag(:div, nil, class: "flex flex-col gap-y-4 items-start") do
            concat simple_format(help_text)
            if help_link.present?
              concat render(V2::ButtonComponent.new(scheme: :link,
                label: "Learn more",
                options: help_link,
                type: :link_external,
                size: :none,
                authz: false) { |b| b.with_icon("arrow_right.svg") })
            end
          end
        end
      end

      icon
    end
  end

  def subgroup? = chart[:subgroup]

  def stacked? = chart[:stacked]

  def line? = chart[:type] == "line"

  def area? = chart[:type] == "area"

  def stacked_bar? = chart[:type] == "stacked-bar"

  def polar_area? = chart[:type] == "polar-area"

  private

  def y_annotations
    return [] if chart[:y_annotations].blank?

    chart[:y_annotations].filter_map do |a|
      {
        y: a[:y].is_a?(Range) ? a[:y].begin : a[:y],
        y2: a[:y].is_a?(Range) ? a[:y].end : nil,
        borderColor: resolve_color(a[:color]),
        fillColor: resolve_color(a[:color]),
        label: {
          textAnchor: "start",
          position: "left",
          offsetX: 7,
          offsetY: 17,
          style: {
            background: resolve_color(a[:color])
          },
          text: a[:text]
        }
      }
    end
  end

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
