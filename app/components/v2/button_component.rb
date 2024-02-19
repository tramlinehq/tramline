class V2::ButtonComponent < V2::BaseComponent
  include Memery

  TYPES = %i[link link_external button dropdown action]
  DROPDOWN_ARROW_STYLES = {
    double: "double_headed_arrow.svg",
    single: "single_headed_arrow.svg",
    none: ""
  }
  BASE_OPTS = "btn group px-2 inline-flex items-center"
  BUTTON_OPTIONS = {
    default: {
      class: "#{BASE_OPTS} text-white bg-blue-700 hover:bg-blue-800 focus:outline-none focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
    },
    light: {
      class: "#{BASE_OPTS} text-main bg-white border border-main-300 focus:outline-none hover:bg-main-100 focus:ring-4 focus:ring-main-200 font-medium rounded-lg dark:bg-main dark:text-white dark:border-main-600 dark:hover:bg-main-700 dark:hover:border-main-600 dark:focus:ring-main-700"
    },
    supporting: {
      class: "#{BASE_OPTS} text-main-500 hover:bg-main-100 dark:bg-main dark:text-main-400 dark:hover:bg-main-700 border-none shadow-none"
    },
    link: {
      class: "#{BASE_OPTS} text-main-500 dark:bg-main dark:text-main-400 border-none shadow-none hover:underline"
    },
    switcher: {
      class: "text-main-500 rounded-lg md:inline-flex hover:text-main hover:bg-main-100 dark:text-main-400 dark:hover:text-white dark:hover:bg-main-700 focus:ring-4 focus:ring-main-300 dark:focus:ring-main-600 items-center"
    },
    naked_icon: {
      class: "text-main-500 rounded-lg hover:text-main dark:text-main-400 dark:hover:text-white",
      icon: true
    },
    avatar_icon: {
      class: "bg-main rounded-full md:mr-0 focus:ring-4 focus:ring-main-300 dark:focus:ring-main-600",
      icon: true
    },
    list_item: {
      class: "flex items-center rounded justify-between block px-4 py-1.5 hover:bg-main-100 dark:hover:bg-main-600 dark:hover:text-white"
    },
    none: {class: ""}
  }
  DISABLED_STYLE = "opacity-30 disabled cursor-not-allowed outline-none focus:outline-none"
  DROPDOWN_STYLE = "p-1 text-sm text-main-700 dark:text-main-200"
  SCHEMES = BUTTON_OPTIONS.keys
  SIZES = {
    none: "",
    base: "px-5 py-2.5 text-base",
    sm: "py-2 px-4 text-sm",
    md: "px-4 py-2 text-base",
    xs: "px-3 py-2 text-xs",
    xxs: "p-1.5 text-xs",
    lg: "px-5 py-3 text-base",
    xl: "px-6 py-3.5 text-base"
  }

  renders_one :title_text
  renders_one :icon, V2::IconComponent

  def initialize(label: nil, scheme: :switcher, type: :button, tooltip: nil, size: :xxs, options: nil, html_options: nil, arrow: :none, authz: true, turbo: true)
    arrow = (scheme == :switcher) ? :double : arrow
    raise ArgumentError, "Invalid scheme" unless SCHEMES.include?(scheme)
    raise ArgumentError, "Invalid button type" unless TYPES.include?(type)
    raise ArgumentError, "Invalid size" unless SIZES.keys.include?(size)
    raise ArgumentError, "Invalid arrow type for dropdown" if DROPDOWN_ARROW_STYLES.keys.exclude?(arrow)
    raise ArgumentError, "Cannot use tooltip with a dropdown" if tooltip && type == :dropdown

    @label = label
    @scheme = scheme
    @type = type
    @size = size
    @tooltip = tooltip
    @options = options
    @html_options = html_options
    @arrow_type = arrow
    @authz = authz
    @disabled = false
    @turbo = turbo
  end

  def before_render
    super
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
    @options = "javascript:void(0);" if disabled?

    _link_to(link_external?, @options, @html_options) do
      concat(icon) if icon?

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
      concat(icon) if icon?

      if title_text?
        concat content_tag(:span, title_text, class: classname)
      elsif @label
        concat content_tag(:span, @label, class: classname)
      end
    end
  end

  def button_component
    return button_tag(@options, @html_options) { render(icon) } if icon_only?

    classname = "ml-1"
    classname = "ml-2" if icon?
    classname += " mr-2" if arrow.present?

    button_tag(@options, @html_options) do
      concat(icon) if icon?

      if title_text?
        concat content_tag(:span, title_text, class: classname)
      elsif @label
        concat content_tag(:span, @label, class: classname)
      end

      concat(render(arrow)) if arrow.present?
    end
  end

  def tooltip_component
    V2::TooltipComponent.new(text: @tooltip) if @tooltip
  end

  # TODO: This is unused & incomplete; port it from ButtonHelper
  # It adds a spinning loader to some types of buttons, perhaps all?
  # It also disables the button while it is showing the spinning loader
  def apply_button_loader(value)
    content_tag(:span, value, class: "group-disabled:hidden") +
      content_tag(:span, "Processing...", class: "hidden group-disabled:inline group-disabled:opacity-60")
  end

  def apply_html_options(options)
    new_options = BUTTON_OPTIONS[@scheme]
    options = options ? options.deep_dup : {}
    options[:class] ||= ""
    options[:class] << " #{new_options[:class]}"
    options[:class] << " #{SIZES[@size]}"
    options[:class] << " #{DISABLED_STYLE}" if disabled?
    options[:class] = options[:class].squish

    options[:data] ||= {}
    options[:data][:turbo] = @turbo

    if @tooltip
      options[:data][:popup_target] = "element"
      options[:data][:action] ||= ""
      options[:data][:action] << " mouseover->popup#show mouseout->popup#hide"
    end

    options.merge(new_options.except(:class))
  end

  def button? = @type == :button

  def action? = @type == :action

  def link? = @type == :link || link_external?

  def link_external? = @type == :link_external

  def icon_only?
    BUTTON_OPTIONS.dig(@scheme, :icon)
  end

  memoize def arrow
    return if @arrow_type.eql?(:none)
    V2::IconComponent.new(DROPDOWN_ARROW_STYLES[@arrow_type], size: :sm)
  end
end
