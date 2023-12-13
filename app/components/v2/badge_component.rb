class V2::BadgeComponent < V2::BaseComponent
  renders_one :icon, V2::IconComponent

  def initialize(text)
    @text = text
  end

  attr_reader :text
end
