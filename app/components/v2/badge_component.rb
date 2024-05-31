class V2::BadgeComponent < V2::BaseComponent
  renders_one :icon, V2::IconComponent
  renders_one :link, ->(label, link) do
    link_to_external(label, link, class: "hover:underline")
  end

  KIND = {
    badge: "text-main dark:text-white text-xs font-medium px-1.5 py-0.5 rounded-md dark:text-secondary-50 border border-main-200 dark:border-main-600 bg-main-100 dark:bg-main-700",
    status_pill: "text-xs font-medium px-2.5 py-0.5 tracking-wideish rounded-md",
    status: "text-lg tracking-wide uppercase box-padding-sm border-default-md"
  }

  def initialize(text: nil, status: nil, color: nil, kind: :status_pill)
    raise ArgumentError, "Invalid kind" unless KIND.key?(kind.to_sym)
    raise ArgumentError if kind == :badge && status.present?
    raise ArgumentError if status.present? && color.present?
    raise ArgumentError if status.nil? && color.nil? && kind != :badge

    @text = text
    @status = status
    @color = color
    @kind = kind
  end

  attr_reader :text, :color

  def background
    return unless @status
    STATUS_COLOR_PALETTE[@status.to_sym].join(" ")
  end

  def pill?
    @kind == :status_pill && !icon?
  end

  def pill
    return unless pill? && @status
    PILL_STATUS_COLOR_PALETTE[@status.to_sym].join(" ")
  end

  def background_style
    return unless color
    "background-color: #{lighten_color(color, 20.0)};"
  end

  def pill_style
    return unless color
    "background-color: #{color};"
  end

  def text_style
    return unless color
    "color: #{darken_color(color, 70.0)};"
  end

  def badge_style
    base_style = KIND[@kind]
    base_style += " #{background}" if @status
    base_style
  end

  private

  def lighten_color(hexcode, amount = 20.0)
    color = Color::RGB.from_html(hexcode)
    lighter_color = color.lighten_by(amount)
    lighter_color.html
  end

  def darken_color(hexcode, amount = 20.0)
    color = Color::RGB.from_html(hexcode)
    lighter_color = color.darken_by(amount)
    lighter_color.html
  end
end
