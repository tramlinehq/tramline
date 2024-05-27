class V2::StatusIndicatorPillComponent < V2::BaseComponent
  def initialize(text:, status: nil, color: nil, pill: true)
    raise ArgumentError if status.present? && color.present?
    raise ArgumentError if status.nil? && color.nil?

    @text = text
    @status = status
    @color = color
    @pill = pill
  end

  attr_reader :text, :color

  def background
    return unless @status
    STATUS_COLOR_PALETTE[@status.to_sym].join(" ")
  end

  def pill?
    @pill
  end

  def pill
    return unless @status
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
    base_style = "inline-flex items-center font-medium"
    base_style += if pill?
      " text-xs px-2.5 py-0.5 rounded-md tracking-wideish"
    else
      " text-lg tracking-wide uppercase box-padding-sm border-default-md"
    end
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
