# frozen_string_literal: true

class AccordionComponent < BaseComponent
  renders_one :title_section

  def initialize(title: nil, auto_hide: true, push_down: false, acts_as_list: false)
    @title = title
    @auto_hide = auto_hide
    @push_down = push_down
    @acts_as_list = acts_as_list
  end

  attr_reader :title, :auto_hide, :push_down

  def content_style
    "px-2.5 bg-backgroundLight-50 py-3" if @acts_as_list
  end

  def title_style
    "px-2.5" if @acts_as_list
  end
end
