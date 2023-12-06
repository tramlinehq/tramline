# frozen_string_literal: true

class V2::ModalComponent < V2::BaseComponent
  BASE_OPTS = {html_options: {data: {action: "click->reveal#toggle"}}}.freeze

  renders_one :body
  renders_one :button, ->(**args) { V2::ButtonComponent.new(**BASE_OPTS.deep_merge(**args)) }

  def initialize(title:)
    @title = title
  end

  attr_reader :title
end
