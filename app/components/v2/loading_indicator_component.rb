class V2::LoadingIndicatorComponent < ViewComponent::Base
  def initialize(text: "loading...")
    @text = text
  end

  attr_reader :text
end
