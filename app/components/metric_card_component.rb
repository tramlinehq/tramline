class MetricCardComponent < ViewComponent::Base
  attr_reader :name, :values, :source
  def initialize(name:, values:, source:)
    @name = name
    @values = values
    @source = source
  end
end
