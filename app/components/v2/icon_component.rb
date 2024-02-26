class V2::IconComponent < V2::BaseComponent
  SIZES = {
    base: "w-3.5 h-3.5",
    sm: "w-3 h-3 ",
    xs: "w-2.5 h-2.5",
    md: "w-4 h-4",
    lg: "w-5 h-5",
    xl: "w-6 h-6",
    xxl: "w-7 h-7",
    xl_3: "w-8 h-8"
  }

  renders_one :tooltip, V2::TooltipComponent

  def initialize(icon, raw_svg: false, rounded: true, size: :base, classes: "")
    raise ArgumentError, "Icon size must be one of #{SIZES.keys.join(", ")}" unless SIZES.key?(size)
    @icon = icon
    @size = size
    @rounded = rounded
    @classes = classes
    @raw_svg = raw_svg
  end

  attr_reader :icon

  def classname
    classname = "inline-flex #{size_class} #{rounded_class}"
    classname += " #{@classes}" if @classes
    classname
  end

  def size_class
    SIZES[@size]
  end

  def rounded_class
    return "rounded-full" if @rounded
    "rounded-sm"
  end

  def external?
    uri = URI.parse(@icon)
    uri.is_a?(URI::HTTP) && !uri.host.nil?
  rescue URI::InvalidURIError
    false
  end

  def internal?
    !external?
  end

  def svg_file?
    @icon.ends_with?(".svg")
  end

  def raw_svg?
    @raw_svg
  end

  def render_component
    if internal? && raw_svg?
      content_tag(:div, icon, class: classname)
    elsif internal? && svg_file?
      inline_svg(icon, classname: classname)
    else
      image_tag(icon, class: classname)
    end
  end
end
