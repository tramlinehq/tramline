class V2::TooltipComponent < ViewComponent::Base
  TOOLTIP_CLASSES = "absolute z-30 px-3 py-2 text-sm font-medium text-white bg-main-900 rounded-lg shadow-sm tooltip dark:bg-main-700"

  renders_one :body

  def initialize(text, placement: "bottom")
    @text = text
    @placement = placement
  end

  attr_reader :text, :placement

  def call
    content_tag(:div,
      class: "inline-flex",
      data: {controller: "popup",
             popup_away_value: "true",
             popup_target_selector_value: "[data-tooltip-popup]",
             popup_placement_value: placement}) do
      concat content_tag(:div, body, class: "w-full", data: {action: "mouseover->popup#show mouseout->popup#hide", popup_target: "element"})
      concat tooltip
    end
  end

  def tooltip
    content_tag(:div, class: TOOLTIP_CLASSES, role: "tooltip", hidden: true, data: {tooltip_popup: true}) do
      concat content_tag(:div,
        nil,
        class: "tooltip-arrow",
        data: {popup_target: "popupArrow"})
      concat text
    end
  end
end
