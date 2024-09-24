# frozen_string_literal: true

class InfoIconComponent < V2::BaseComponent
  def initialize(placement: "top")
    @placement = placement
    @icon = V2::IconComponent.new("v2/info.svg", size: :md, classes: "text-secondary")
  end
end
