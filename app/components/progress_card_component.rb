class ProgressCardComponent < ViewComponent::Base
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

  attr_reader :name, :current, :subtitle, :provider

  def text_size
    TEXT_SIZE[@size]
  end
end
