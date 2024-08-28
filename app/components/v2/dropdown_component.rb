class V2::DropdownComponent < V2::BaseComponent
  DROPDOWN_ACTIONS = {popup_target: "element", action: "click->popup#toggle"}.freeze
  BASE_BUTTON_OPTS = {scheme: :switcher, type: :action, size: :xxs, html_options: {data: DROPDOWN_ACTIONS}}.freeze

  renders_one :button, ->(**args) do
    args = args.merge(authz: @authz) # trickle down the auth setting to the button
    V2::ButtonComponent.new(**BASE_BUTTON_OPTS.deep_merge(args))
  end

  renders_one :subtext
  renders_many :item_groups, ->(list_style: nil) { ItemGroupComponent.new(list_style: list_style, authz: @authz) }

  def initialize(authz: true)
    @authz = authz
    @disabled = false
  end

  def popup_data_attrs
    if disabled?
      {}
    else
      {
        data: {
          controller: "popup",
          popup_away_value: "true",
          popup_target_selector_value: "[data-dropdown-reveal]",
          popup_offset_value: "[0,8]"
        }
      }
    end
  end

  class ItemGroupComponent < V2::BaseComponent
    DROPDOWN_STYLE = "text-sm text-main-700 dark:text-main-200 leading-none font-medium"
    LIST_ITEM_STYLE = "p-0.5"
    renders_many :items, ->(**args) { ItemComponent.new(**args) }

    def initialize(list_style: DROPDOWN_STYLE, authz: true)
      @list_style = list_style
      @authz = authz
    end

    def call
      content_tag(:ul, class: @list_style) do
        items.collect do |item|
          concat content_tag(:li, item, class: LIST_ITEM_STYLE)
        end
      end
    end

    class ItemComponent < V2::BaseComponent
      def initialize(link: nil, selected: false)
        @link = link || {}
        @selected = selected
      end

      ITEM_STYLE = "flex items-center rounded justify-between block px-4 py-1.5 hover:bg-main-100 dark:hover:bg-main-600 dark:hover:text-white text-sm"
      SELECTED_CHECK_STYLE = "ml-4 w-3 h-3 text-green-500"

      def call
        if @link.present?
          _link_to(@link[:external], link_path, **link_params) do
            concat content
            concat inline_svg("selected_check.svg", classname: SELECTED_CHECK_STYLE) if @selected
          end
        else
          content_tag(:span, class: ITEM_STYLE) do
            content
          end
        end
      end

      def link_path
        @link[:path]
      end

      def link_class
        {class: @link[:class].presence || ITEM_STYLE}
      end

      def link_params
        link_class.merge(@link.except(:class))
      end
    end
  end
end
