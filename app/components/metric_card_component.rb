class MetricCardComponent < ViewComponent::Base
  attr_reader :name, :values, :provider
  def initialize(name:, values:, provider:)
    @name = name
    @values = values
    @provider = provider
  end
end
