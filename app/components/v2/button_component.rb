# frozen_string_literal: true

class V2::ButtonComponent < V2::BaseComponent
  TYPES = %i[link button].freeze
  BASE_OPTS = "btn group px-2"
  BUTTON_OPTIONS = {
    default: {
      class: "#{BASE_OPTS} text-white bg-blue-700 hover:bg-blue-800 focus:outline-none focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
    },
    dark: {
      class: "#{BASE_OPTS} text-white bg-gray-800 hover:bg-gray-900 focus:outline-none focus:ring-4 focus:ring-gray-300 font-medium rounded-lg text-sm dark:bg-gray-800 dark:hover:bg-gray-700 dark:focus:ring-gray-700 dark:border-gray-700"
    },
    light: {
      class: "#{BASE_OPTS} text-gray-900 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm dark:bg-gray-800 dark:text-white dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700"
    },
    primary: {
      class: "#{BASE_OPTS} text-white bg-green-700 hover:bg-green-800 focus:outline-none focus:ring-4 focus:ring-green-300 font-medium rounded-lg text-sm text-center dark:bg-green-600 dark:hover:bg-green-700 dark:focus:ring-green-800"
    },
    danger: {
      class: "#{BASE_OPTS} text-white bg-red-700 hover:bg-red-800 focus:outline-none focus:ring-4 focus:ring-red-300 font-medium rounded-lg text-sm text-center dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
    },
    neutral: {
      class: "#{BASE_OPTS} text-white bg-yellow-400 hover:bg-yellow-500 focus:outline-none focus:ring-4 focus:ring-yellow-300 font-medium rounded-lg text-sm text-center dark:focus:ring-yellow-900"
    },
    supporting: {
      class: "#{BASE_OPTS} text-gray-500 hover:bg-gray-200 font-medium text-sm dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700 border-none shadow-none"
    },
    disabled:
      {
        class: "#{BASE_OPTS} opacity-30 disabled cursor-not-allowed bg-transparent",
        disabled: true
      }
  }
  SCHEMES = BUTTON_OPTIONS.keys
  SIZES = {
    base: "px-5 py-2.5 text-sm",
    sm: "px-3 py-2 text-sm",
    xs: "px-3 py-2 text-xs",
    xxs: "p-1.5 text-xs",
    lg: "px-5 py-3 text-base",
    xl: "px-6 py-3.5 text-base"
  }

  def initialize(label: nil, scheme: :default, type: :button, visual_icon: nil, tooltip: nil, size: :base, options: nil, html_options: nil)
    raise ArgumentError, "Invalid scheme" unless SCHEMES.include?(scheme)
    raise ArgumentError, "Invalid button type" unless TYPES.include?(type)
    raise ArgumentError, "Invalid size" unless SIZES.keys.include?(size)

    @label = label
    @scheme = scheme
    @type = type
    @size = size
    @visual_icon = visual_icon
    @tooltip = tooltip
    @options = options
    @html_options = html_options
  end

  def before_render
    @html_options = apply_html_options(@html_options)
  end

  def render_component
    if link?
      link_to_component
    elsif button?
      button_to_component
    end
  end

  def link_to_component
    classname = ""
    classname = "ml-2" unless icon_only?

    link_to(@options, @html_options) do
      concat icon

      if content
        concat content_tag(:span, content, class: classname)
      else
        if @label
          concat content_tag(:span, @label, class: classname)
        end
      end
    end
  end

  def button_to_component
    classname = ""
    classname = "ml-2" unless icon_only?

    button_to(@options, @html_options) do
      concat icon
      if content
        concat content_tag(:span, content, class: classname)
      else
        if @label
          concat content_tag(:span, @label, class: classname)
        end
      end
    end
  end

  def tooltip_component
    V2::TooltipComponent.new(text: @tooltip) if @tooltip
  end

  private

  def apply_button_loader(value)
    content_tag(:span, value, class: "group-disabled:hidden") +
      content_tag(:span, "Processing...", class: "hidden group-disabled:inline group-disabled:opacity-60")
  end

  def apply_html_options(options)
    new_options = BUTTON_OPTIONS[scheme]
    options ||= {}
    options[:class] ||= "".dup
    options[:class] << " #{new_options[:class]}"
    options[:class] << " #{SIZES[@size]}"
    options[:class].squish

    if @tooltip
      options[:data] ||= {}
      options[:data][:popup_target] = "element"
      options[:data][:action] = "mouseover->popup#show mouseout->popup#hide"
    end

    options.merge(new_options.except(:class))
  end

  def link?
    @type == :link

  end

  def button?
    @type == :button
  end

  def icon
    inline_svg(@visual_icon, classname: "w-4 h-4 items-center") if @visual_icon
  end

  def scheme
    @scheme = :disabled unless helpers.writer?
    @scheme
  end

  def icon_only?
    !@label && !content && @visual_icon
  end
end
