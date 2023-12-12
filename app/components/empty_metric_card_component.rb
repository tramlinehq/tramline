class EmptyMetricCardComponent < ViewComponent::Base
  def initialize(name:)
    @name = name
  end

  attr_reader :name
end
