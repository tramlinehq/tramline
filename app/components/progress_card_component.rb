class ProgressCardComponent < ViewComponent::Base
  TEXT_SIZE = {
    sm: "text-base",
    base: "text-xl"
  }

  def initialize(name:, current:, subtitle:, provider:, external_url:, size: :base)
    @name = name
    @current = current
    @subtitle = subtitle
    @provider = provider
    @external_url = external_url
    @size = size
  end

  attr_reader :name, :current, :subtitle, :provider, :external_url, :size

  def text_size
    TEXT_SIZE[@size]
  end
end
