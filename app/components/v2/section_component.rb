# frozen_string_literal: true

class V2::SectionComponent < V2::BaseComponent
  STYLES = %i[boxed titled].freeze

  def initialize(style: :boxed, title: nil)
    raise ArgumentError, "Invalid style: #{style}" unless STYLES.include?(style)
    raise ArgumentError, "Title must exist if style is titled" if style == :titled && title.blank?

    @style = style
    @title = title
  end

  attr_reader :title

  def boxed?
    @style == :boxed
  end

  def titled?
    @style == :titled
  end
end
