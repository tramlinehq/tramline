class V2::HorizontalDataSetComponent < V2::BaseComponent
  SEPARATORS = [:solid, :dashed]
  renders_many :data_sets, "DataSetComponent"

  def initialize(separator: :dashed, bg_color: false)
    raise ArgumentError, "Invalid separator #{separator}" unless SEPARATORS.include?(separator)
    @separator = separator
    @bg_color = bg_color
  end

  def separator
    "last:border-0 border-l border-#{@separator} border-main-300"
  end

  def bg_color
    "bg-main-100" if @bg_color
  end

  def last_set?(i)
    data_sets.length == i + 1
  end

  class DataSetComponent < V2::BaseComponent
    renders_one :tooltip, V2::TooltipComponent

    def initialize(title:, uppercase_title: true)
      @title = title
      @uppercase_title = uppercase_title
    end

    attr_reader :title

    def uppercase_title
      "uppercase" if @uppercase_title
    end

    def call
      content
    end
  end
end
