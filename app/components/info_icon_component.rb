# frozen_string_literal: true

class InfoIconComponent < BaseComponent
  def initialize(placement: "top")
    @placement = placement
    @icon = IconComponent.new("info.svg", size: :md, classes: "text-secondary")
  end
end
