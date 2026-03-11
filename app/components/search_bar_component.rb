# frozen_string_literal: true

class SearchBarComponent < BaseComponent
  DEFAULT_FRAME = "search_bar_and_results"
  DEFAULT_QUERY_FIELD = "search_pattern"
  QUERY_FIELD_SIZE_TO_WIDTH = {
    none: "",
    sm: "min-w-[12rem] sm:min-w-[18rem]",
    md: "min-w-[14rem] sm:min-w-[22rem]"
  }.freeze

  renders_one :notice

  def initialize(search_name:, search_value:, search_placeholder:, form_url:, turbo_frame: DEFAULT_FRAME, query_field: DEFAULT_QUERY_FIELD, turbo_action: nil, query_field_size: :none)
    query_field_size = query_field_size.to_sym
    raise ArgumentError, "Invalid query field size" unless QUERY_FIELD_SIZE_TO_WIDTH.key?(query_field_size)

    @search_name = search_name
    @search_value = search_value
    @search_placeholder = search_placeholder
    @form_url = form_url
    @turbo_frame = turbo_frame
    @query_field = query_field
    @turbo_action = turbo_action
    @query_field_size = query_field_size
  end

  attr_reader :search_name, :search_value, :search_placeholder, :form_url, :turbo_frame, :query_field, :turbo_action

  def query_field_width
    QUERY_FIELD_SIZE_TO_WIDTH.fetch(@query_field_size, QUERY_FIELD_SIZE_TO_WIDTH[:none])
  end
end
