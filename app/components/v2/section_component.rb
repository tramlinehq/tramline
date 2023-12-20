# frozen_string_literal: true

class V2::SectionComponent < V2::BaseComponent
  STYLES = %i[boxed titled].freeze

  renders_one :sidenote

  def initialize(style: :boxed, title: nil, subtitle: nil)
    raise ArgumentError, "Invalid style: #{style}" unless STYLES.include?(style)
    raise ArgumentError, "Title must exist if style is titled" if style == :titled && title.blank?
    raise ArgumentError, "Subtitle can only exist when title is supplied" if title.blank? && subtitle.present?

    @style = style
    @title = title
    @subtitle = subtitle
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
end
