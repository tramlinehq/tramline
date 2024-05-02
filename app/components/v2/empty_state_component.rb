class V2::EmptyStateComponent < V2::BaseComponent
  TYPES = [:giant, :subdued, :tiny]

  def initialize(text:, banner_image:, title: "", type: :giant)
    raise ArgumentError, "Invalid type: #{type}" unless TYPES.include?(type)
    raise ArgumentError, "Cannot use block with :subdued type" if type == :subdued && block_given?

    @title = title
    @text = text
    @banner_image = banner_image
    @type = type
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
end
