# frozen_string_literal: true

class V2::AccordionComponent < V2::BaseComponent
  renders_one :title_section

  def initialize(title: nil, auto_hide: true, push_down: false)
    @title = title
    @auto_hide = auto_hide
    @push_down = push_down
  end

  attr_reader :title, :auto_hide, :push_down
end
