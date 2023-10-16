class ProgressCardComponent < ViewComponent::Base
  attr_reader :name, :current, :subtitle, :source
  def initialize(name:, current:, subtitle:, source:)
    @name = name
    @current = current
    @subtitle = subtitle
    @source = source
  end

  def fraction
    "#{current}%"
  end
end
