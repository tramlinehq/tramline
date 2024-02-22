class ProgressCardComponent < ViewComponent::Base
  attr_reader :name, :current, :subtitle, :provider
  TEXT_SIZE = {
    sm: "text-base",
    base: "text-xl"
  }

  def initialize(name:, current:, subtitle:, provider:, size: :base)
    @name = name
    @current = current
    @subtitle = subtitle
    @provider = provider
    @size = size
  end

  def fraction
    "#{current}%"
  end

  def text_size
    TEXT_SIZE[@size]
  end
end
