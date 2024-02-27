class V2::EmptyStateComponent < ViewComponent::Base
  TYPES = [:giant, :subdued]

  def initialize(title: "", text:, banner_image:, type: :giant)
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
end
