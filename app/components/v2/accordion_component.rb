# frozen_string_literal: true

class V2::AccordionComponent < V2::BaseComponent
  def initialize(title:, auto_hide: true)
    @title = title
    @auto_hide = auto_hide
  end

  attr_reader :title, :auto_hide
end
