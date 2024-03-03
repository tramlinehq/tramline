class V2::BadgeComponent < V2::BaseComponent
  BASE_LINK_OPTS = {scheme: :link, type: :link_external, size: :xxs, arrow: :none}.freeze
  renders_one :icon, V2::IconComponent
  renders_one :link, ->(label, link) do
    link_to_external(label, link, class: "hover:underline")
  end

  def initialize(text = nil)
    @text = text
  end

  attr_reader :text
end
