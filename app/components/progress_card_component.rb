class ProgressCardComponent < ViewComponent::Base
  attr_reader :name, :current, :subtitle, :provider
  def initialize(name:, current:, subtitle:, provider:)
    @name = name
    @current = current
    @subtitle = subtitle
    @provider = provider
  end

  def fraction
    "#{current}%"
  end
end
