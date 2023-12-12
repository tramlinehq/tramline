# frozen_string_literal: true

class V2::BadgeComponent < V2::BaseComponent

  def initialize(text:, icon:)
    raise ArgumentError, "icon suffix must be png or svg" unless icon.ends_with?(".png") || icon.ends_with?(".svg")
    @text = text
    @icon = icon
  end

  attr_reader :text, :icon

  def image
    if icon.ends_with?(".svg")
      inline_svg(icon, classname: "w-3 h-3 inline-flex")
    else
      image_tag(icon, class: "h-3 w-3 inline-flex")
    end
  end
end
