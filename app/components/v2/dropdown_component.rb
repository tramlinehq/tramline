# frozen_string_literal: true

class V2::DropdownComponent < V2::BaseComponent
  ARROW_STYLES = {
    double: "double_headed_arrow.svg",
    single: "single_headed_arrow.svg",
    none: "",
  }

  DROPDOWN_STYLE = {
    switcher: {
      cta: "text-sm font-medium items-center p-2 pr-3 pl-4 text-gray-500 rounded-lg md:inline-flex hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-white dark:hover:bg-gray-700 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600",
      list: "p-1 text-sm text-gray-700 dark:text-gray-200"
    },
    icon_only: {
      cta: "flex text-sm bg-gray-800 rounded-full md:mr-0 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600",
      list: "p-1 text-gray-500 dark:text-gray-400"
    },
    button: {},
    tooltip: {},
  }

  renders_one :title_text
  renders_one :subtext
  renders_one :visual_icon, ->(**args) { VisualIconComponent.new(**args) }
  renders_many :item_groups, -> { ItemGroupComponent.new(list_style: list_style) }

  class ItemGroupComponent < V2::BaseComponent
    renders_many :items

    def initialize(list_style: DROPDOWN_STYLE[:icon_only][:list])
      @list_style = list_style
    end

    def call
      content_tag(:ul, class: @list_style) do
        items.collect do |item|
          concat content_tag(:li, item)
        end
      end
    end
  end

  class VisualIconComponent < V2::BaseComponent
    def initialize(external_img: nil, internal_svg: nil)
      raise ArgumentError, "can only be external or internal" if external_img.present? && internal_svg.present?

      @external_img = external_img
      @internal_svg = internal_svg
    end

    def call
      if @external_img.present?
        image_tag(@external_img, class: "w-8 h-8 rounded-full")
      elsif @internal_svg.present?
        inline_svg(@internal_svg + ".svg", classname: "w-4 h-4 rounded-full")
      end
    end
  end

  def initialize(type: :button, arrow: :none)
    raise ArgumentError, "Invalid dropdown type" unless DROPDOWN_STYLE.include?(type)
    raise ArgumentError, "Invalid arrow type" unless ARROW_STYLES.keys.include?(arrow)

    @type = type
    @arrow_type = arrow
  end

  def arrow
    return if @arrow_type.eql?(:none)
    inline_svg(ARROW_STYLES[@arrow_type], classname: "w-3 h-3")
  end

  def cta_style
    DROPDOWN_STYLE[@type][:cta]
  end

  def list_style
    DROPDOWN_STYLE[@type][:list]
  end

  def visual_icon_only?
    visual_icon? && !title_text?
  end
end
