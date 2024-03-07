class EmptyMetricCardComponent < ViewComponent::Base
  TEXT_SIZE = {
    base: "text-xl",
    sm: "text-sm"
  }

  def initialize(name:, help_text: nil, size: :base)
    @name = name
    @size = size
    @help_text = help_text
  end

  attr_reader :name

  def text_size
    TEXT_SIZE[@size]
  end

  def corner_icon
    if @help_text.present?
      icon = V2::IconComponent.new("v2/info.svg", size: :md, classes: "text-main-500")

      icon.with_tooltip(@help_text, placement: "top", type: :detailed) do |tooltip|
        tooltip.with_detailed_text do
          content_tag(:div, nil, class: "flex flex-col gap-y-4 items-start") do
            concat simple_format(@help_text)
          end
        end
      end

      icon
    end
  end
end
