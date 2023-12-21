class V2::IconComponent < V2::BaseComponent
  SIZES = {
    base: "w-3.5 h-3.5",
    sm: "w-3 h-3 ",
    xs: "w-2.5 h-2.5",
    md: "w-4 h-4",
    lg: "w-5 h-5",
    xl_3: "w-8 h-8"
  }

  def initialize(icon, rounded: true, size: :base, classes: "")
    raise ArgumentError, "Icon size must be one of #{SIZES.keys.join(", ")}" unless SIZES.keys.include?(size)
    @icon = icon
    @size = size
    @rounded = rounded
    @classes = classes
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
    "rounded-full" if @rounded
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

  def svg?
    @icon.ends_with?(".svg")
  end
end
