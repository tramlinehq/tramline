# frozen_string_literal: true

class V2::TooltipComponent < ViewComponent::Base
  def initialize(text:)
    @text = text
  end

  attr_reader :text
end
