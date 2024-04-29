class V2::RangeSliderComponent < V2::BaseComponent
  def initialize(allowed_range:, step:, colors:, form:, from_method:, to_method:)
    @allowed_range = allowed_range
    @step = step
    @colors = colors
    @form = form
    @from_method = from_method
    @to_method = to_method
  end

  attr_reader :form, :from_method, :to_method, :allowed_range, :step

  def below_range_color
    @colors[:below_range]
  end

  def within_range_color
    @colors[:within_range]
  end

  def above_range_color
    @colors[:above_range]
  end
end
