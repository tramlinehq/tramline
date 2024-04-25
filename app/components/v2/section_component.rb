class V2::SectionComponent < V2::BaseComponent
  STYLES = %i[boxed titled].freeze
  SIZES = %i[default compact].freeze

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

  def default?
    @size == :default
  end

  def compact?
    @size == :compact
  end

  def content_gap
    default? ? "mt-6" : "mt-2"
  end

  def section_margin
    default? ? "my-10" : "my-6"
  end

  def separator_gap
    default? ? "gap-x-5" : "gap-x-3"
  end

  def heading_size
    default? ? "heading-2" : "heading-3"
  end
end
