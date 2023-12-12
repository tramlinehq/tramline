# frozen_string_literal: true

class V2::HorizontalDataSetComponent < V2::BaseComponent
  SEPARATORS = [:solid, :dashed]

  renders_many :data_sets, "DataSetComponent"

  def initialize(separator: :dashed, bg_color: false)
    raise ArgumentError, "Invalid separator #{separator}" unless SEPARATORS.include?(separator)
    @separator = separator
    @bg_color = bg_color
  end

  def separator
    "last:border-0 border-l border-#{@separator} border-gray-300"
  end

  def bg_color
    "bg-gray-100" if @bg_color
  end

  def last_set?(i)
    data_sets.length == i + 1
  end

  class DataSetComponent < V2::BaseComponent
    def initialize(title:, uppercase_title: true, icon: nil, lines: [])
      @title = title
      @uppercase_title = uppercase_title
      @lines = lines
      @icon = icon
    end

    attr_reader :title, :lines

    def uppercase_title
      "uppercase" if @uppercase_title
    end

    def icon
      return unless @icon
      inline_svg("v2/#{@icon}.svg", classname: "w-3 h-3 inline-flex")
    end
  end
end
