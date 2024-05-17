class ProgressCardComponent < ViewComponent::Base
  def initialize(name:, current:, subtitle:, provider:, external_url:, size: nil)
    @name = name
    @current = current
    @subtitle = subtitle
    @provider = provider
    @external_url = external_url
    @size = size
  end

  attr_reader :name, :current, :subtitle, :provider, :external_url, :size
end
