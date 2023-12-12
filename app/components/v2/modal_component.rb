# frozen_string_literal: true

class V2::ModalComponent < V2::BaseComponent
  BASE_OPTS = {html_options: {data: {action: "click->reveal#toggle"}}}.freeze
  SIZES = [:xsmall, :small, :medium, :large, :full].freeze

  renders_one :body
  renders_one :button, ->(**args) { V2::ButtonComponent.new(**BASE_OPTS.deep_merge(**args)) }

  def initialize(title:, size: :full)
    @title = title
    @size = size
  end

  attr_reader :title

  def max_width
    case @size
    when :xxsmall then "max-w-xs"
    when :xsmall then "max-w-sm"
    when :small then "max-w-md"
    when :medium then "max-w-lg"
    when :large then "max-w-xl"
    when :full then "max-w-2xl"
    else "max-w-xl"
    end
  end
end
