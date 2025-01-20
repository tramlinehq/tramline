class SectionComponent < BaseComponent
  STYLES = %i[boxed titled].freeze
  SIZES = %i[default compact micro].freeze

  renders_one :sidenote

  def initialize(style: :boxed, title: nil, subtitle: nil, size: :default)
    raise ArgumentError, "Invalid style: #{style}" unless STYLES.include?(style)
    raise ArgumentError, "Title must exist if style is titled" if style == :titled && title.nil?
    raise ArgumentError, "Subtitle can only exist when title is supplied" if title.blank? && subtitle.present?
    raise ArgumentError, "Invalid size: #{size}" unless SIZES.include?(size)

    @style = style
    @title = title
    @subtitle = subtitle
    @size = size
  end

  attr_reader :title

  def boxed?
    @style == :boxed
  end

  def subtitle
    @subtitle&.upcase_first
  end

  def titled?
    @style == :titled
  end

  def content_gap
    case @size
    when :default
      "mt-6"
    when :compact
      "mt-4"
    when :micro
      "mt-3"
    else
      raise ArgumentError, "Invalid size: #{@size}"
    end
  end

  def section_margin
    case @size
    when :default
      "my-10"
    when :compact
      "my-6"
    when :micro
      "mt-3"
    else
      raise ArgumentError, "Invalid size: #{@size}"
    end
  end

  def separator_gap
    case @size
    when :default
      "gap-x-5"
    when :compact, :micro
      "gap-x-1.5"
    else
      raise ArgumentError, "Invalid size: #{@size}"
    end
  end

  def heading_size
    case @size
    when :default
      "heading-2"
    when :compact
      "heading-4"
    when :micro
      "heading-5"
    else
      raise ArgumentError, "Invalid size: #{@size}"
    end
  end
end
