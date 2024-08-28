class V2::BadgeComponent < V2::BaseComponent
  renders_one :icon, V2::IconComponent
  renders_one :link, ->(label, link) do
    link_to_external(label, link, class: "hover:underline")
  end

  KIND = {
    badge: "text-main dark:text-white text-xs font-medium px-1.5 py-0.5 rounded-md dark:text-secondary-50 border border-main-200 dark:border-main-600 bg-main-100 dark:bg-main-700",
    status_pill: "text-xs font-medium px-2.5 py-0.5 rounded-md",
    status: "text-lg tracking-wide uppercase box-padding-sm border-default-md",
    featured: "text-xs font-medium px-2 py-0.5 rounded-md bg-main-500 text-main-100 tracking-wideish uppercase"
  }

  STATUS_KINDS = [:status, :status_pill]

  def initialize(text: nil, status: nil, color: nil, kind: :status_pill)
    raise ArgumentError, "Invalid kind" unless KIND.key?(kind.to_sym)
    raise ArgumentError if !kind.in?(STATUS_KINDS) && status.present?
    raise ArgumentError if status.present? && color.present?
    raise ArgumentError if kind.in?(STATUS_KINDS) && status.nil? && color.nil?

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

  def colored_badge_class
    "badge-#{badge_id}"
  end

  def colored_pill_class
    "pill-#{badge_id}"
  end

  def colored_text_class
    "text-#{badge_id}"
  end

  def inline_styles
    return unless color

    content_tag :style, nonce: content_security_policy_nonce do
      concat ".#{colored_badge_class} { background-color: #{lighten_color(color, 20.0)}; }"
      concat ".#{colored_pill_class} { background-color: #{color}; }"
      concat ".#{colored_text_class} { color: #{darken_color(color, 70.0)}; }"
    end
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

  def badge_id
    @badge_id ||= SecureRandom.hex(4)
  end
end
