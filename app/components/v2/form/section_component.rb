# frozen_string_literal: true

class V2::Form::SectionComponent < V2::BaseComponent
  renders_one :description

  def initialize(heading:, html_options: {})
    @heading = heading
    @html_options = html_options
  end

  attr_reader :heading

  def data_fields
    return unless @html_options[:data]
    @html_options[:data].map do |attr, value|
      "data-#{attr.to_s.dasherize}=#{value}"
    end.join(" ")
  end

  def hidden?
    @html_options[:hidden]
  end
end
