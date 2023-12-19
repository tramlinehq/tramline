class V2::LoadingIndicatorComponent < ViewComponent::Base
  def initialize(text: "Loading...", pulse: true)
    @text = text
    @pulse = pulse
  end

  attr_reader :text

  def pulse
    "animate-pulse" if @pulse
  end
end
