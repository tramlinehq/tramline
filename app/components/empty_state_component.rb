class EmptyStateComponent < BaseComponent
  TYPES = [:giant, :subdued, :tiny]

  def initialize(text:, banner_image:, title: "", type: :giant, margin_top: true)
    raise ArgumentError, "Invalid type: #{type}" unless TYPES.include?(type)
    raise ArgumentError, "Cannot use block with :subdued type" if type == :subdued && block_given?

    @title = title
    @text = text
    @banner_image = banner_image
    @type = type
    @margin_top = margin_top
  end

  attr_reader :title, :text, :banner_image

  def giant?
    @type == :giant
  end

  def subdued?
    @type == :subdued
  end

  def tiny?
    @type == :tiny
  end

  def margin_top
    if @margin_top
      if giant?
        "mt-24"
      elsif subdued?
        "mt-12"
      elsif tiny?
        ""
      end
    else
      ""
    end
  end
end
