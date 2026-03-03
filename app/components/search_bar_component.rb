# frozen_string_literal: true

class SearchBarComponent < BaseComponent
  DEFAULT_FRAME = "search_bar_and_results"
  DEFAULT_QUERY_FIELD = "search_pattern"

  renders_one :notice

  def initialize(search_name:, search_value:, search_placeholder:, form_url:, turbo_frame: DEFAULT_FRAME, query_field: DEFAULT_QUERY_FIELD, turbo_action: nil)
    @search_name = search_name
    @search_value = search_value
    @search_placeholder = search_placeholder
    @form_url = form_url
    @turbo_frame = turbo_frame
    @query_field = query_field
    @turbo_action = turbo_action
  end

  attr_reader :search_name, :search_value, :search_placeholder, :form_url, :turbo_frame, :query_field, :turbo_action
end
