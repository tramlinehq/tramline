class EmptyMetricCardComponent < ViewComponent::Base
  TEXT_SIZE = {
    base: "text-xl",
    sm: "text-sm"
  }

  def initialize(name:, size: :base)
    @name = name
    @size = size
  end

  attr_reader :name

  def text_size
    TEXT_SIZE[@size]
  end
end
