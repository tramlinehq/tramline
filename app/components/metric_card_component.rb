class MetricCardComponent < ViewComponent::Base
  attr_reader :name, :values, :provider, :external_url
  def initialize(name:, values:, provider:, external_url:)
    @name = name
    @values = values
    @provider = provider
    @external_url = external_url
  end
end
