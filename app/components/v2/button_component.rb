class V2::ButtonComponent < V2::BaseComponent
  TYPES = %i[link link_external button dropdown action]
  DROPDOWN_ARROW_STYLES = {
    double: "double_headed_arrow.svg",
    single: "single_headed_arrow.svg",
    none: ""
  }
  BASE_OPTS = "btn group px-2 flex items-center"
  BUTTON_OPTIONS = {
    default: {
      class: "#{BASE_OPTS} text-white bg-blue-700 hover:bg-blue-800 focus:outline-none focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
    },
    light: {
      class: "#{BASE_OPTS} text-gray-900 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700"
    },
    supporting: {
      class: "#{BASE_OPTS} text-gray-500 hover:bg-gray-100 text-sm dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700 border-none shadow-none"
    },
    switcher: {
      class: "text-gray-500 rounded-lg md:inline-flex hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-white dark:hover:bg-gray-700 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600 items-center"
    },
    naked_icon: {
      class: "text-gray-500 rounded-lg hover:text-gray-900 dark:text-gray-400 dark:hover:text-white",
      icon: true
    },
    avatar_icon: {
      class: "bg-gray-800 rounded-full md:mr-0 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600",
      icon: true
    },
    disabled:
      {
        class: "#{BASE_OPTS} opacity-30 disabled cursor-not-allowed bg-transparent",
        disabled: true
      }
  }
  DROPDOWN_STYLE = "p-1 text-sm text-gray-700 dark:text-gray-200"
  SCHEMES = BUTTON_OPTIONS.keys
  SIZES = {
    none: "",
    base: "px-5 py-2.5 text-sm",
    sm: "py-2 px-4 text-sm",
    xs: "px-3 py-2 text-xs",
    xxs: "p-1.5 text-xs",
    lg: "px-5 py-3 text-base",
    xl: "px-6 py-3.5 text-base"
  }
  VISUAL_ICON_TYPES = %i[external internal]

  renders_one :title_text

  def initialize(label: nil, scheme: :switcher, type: :button, visual_icon: nil, visual_icon_type: :internal, tooltip: nil, size: :xxs, options: nil, html_options: nil, arrow: nil)
    arrow = (arrow.nil? && type == :action) ? :double : :none
    raise ArgumentError, "Invalid scheme" unless SCHEMES.include?(scheme)
    raise ArgumentError, "Invalid button type" unless TYPES.include?(type)
    raise ArgumentError, "Invalid size" unless SIZES.keys.include?(size)
    raise ArgumentError, "Invalid arrow type for dropdown" if DROPDOWN_ARROW_STYLES.keys.exclude?(arrow)
    raise ArgumentError, "Cannot use tooltip with a dropdown" if tooltip && type == :dropdown
    raise ArgumentError, "Visual Icon can only be internal or external" if visual_icon && VISUAL_ICON_TYPES.exclude?(visual_icon_type)

    @label = label
    @scheme = scheme
    @type = type
    @size = size
    @visual_icon = visual_icon
    @visual_icon_type = visual_icon_type
    @tooltip = tooltip
    @options = options
    @html_options = html_options
    @arrow_type = arrow
  end

  def before_render
    @html_options = apply_html_options(@html_options)
  end

  def render_component
    if link?
      link_to_component
    elsif button?
      button_to_component
    elsif action?
      button_component
    end
  end

  def link_to_component
    classname = ""
    classname = "ml-2" unless icon_only?

    _link_to(link_external?, @options, @html_options) do
      concat icon

      if title_text?
        concat content_tag(:span, title_text, class: classname)
      elsif @label
        concat content_tag(:span, @label, class: classname)
      end
    end
  end

  def button_to_component
    classname = ""
    classname = "ml-2" unless icon_only?

    button_to(@options, @html_options) do
      concat icon

      if title_text?
        concat content_tag(:span, title_text, class: classname)
      elsif @label
        concat content_tag(:span, @label, class: classname)
      end
    end
  end

  def button_component
    return button_tag(@options, @html_options) { icon } if icon_only?

    classname = "ml-1"
    classname = "ml-2" if icon.present?

    button_tag(@options, @html_options) do
      concat icon
      concat content_tag(:span, "Open menu", class: "sr-only")
      if title_text?
        concat content_tag(:span, title_text, class: classname)
      elsif @label
        concat content_tag(:span, @label, class: classname)
      end
      concat arrow
    end
  end

  def tooltip_component
    V2::TooltipComponent.new(text: @tooltip) if @tooltip
  end

  def apply_button_loader(value)
    content_tag(:span, value, class: "group-disabled:hidden") +
      content_tag(:span, "Processing...", class: "hidden group-disabled:inline group-disabled:opacity-60")
  end

  def apply_html_options(options)
    new_options = BUTTON_OPTIONS[get_scheme]
    options = options ? options.dup : {}
    options[:class] ||= ""
    options[:class] << " #{new_options[:class]}"
    options[:class] << " #{SIZES[@size]}"
    options[:class] = options[:class].squish

    options[:data] ||= {}

    if @tooltip
      options[:data][:popup_target] = "element"
      options[:data][:action] = "mouseover->popup#show mouseout->popup#hide"
    end

    options.merge(new_options.except(:class))
  end

  def link? = @type == :link || link_external?

  def link_external? = @type == :link_external

  def button? = @type == :button

  def action? = @type == :action

  ARROW_STYLE = "w-3 h-3 ml-2"
  EXTERNAL_ICON_STYLE = "w-8 h-8 rounded-full"
  INTERNAL_ICON_STYLE = "w-4 h-4 rounded-full"

  def icon
    return unless @visual_icon

    if @visual_icon_type.eql?(:external)
      image_tag(@visual_icon, class: EXTERNAL_ICON_STYLE)
    else
      inline_svg(@visual_icon + ".svg", classname: INTERNAL_ICON_STYLE)
    end
  end

  def get_scheme
    @scheme = :disabled unless helpers.writer?
    @scheme
  end

  def icon_only?
    BUTTON_OPTIONS.dig(get_scheme, :icon)
  end

  def arrow
    return if @arrow_type.eql?(:none)
    inline_svg(DROPDOWN_ARROW_STYLES[@arrow_type], classname: ARROW_STYLE)
  end
end
