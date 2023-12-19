class V2::LoadingIndicatorComponent < ViewComponent::Base
  def initialize(text: "Loading...", pulse: true, typewriter_only: false)
    @text = text
    @pulse = pulse
    @typewriter_only = typewriter_only
  end

  attr_reader :text

  def pulse
    "animate-pulse" if @pulse || !@typewriter_only
  end
end
