# frozen_string_literal: true

class SearchBarComponent < BaseComponent
  DEFAULT_FRAME = "search_bar_and_results"
  DEFAULT_QUERY_FIELD = "search_pattern"

  renders_one :notice
  renders_one :search, types: {
    form: ->(url:, **options) {
      form_with url:, method: :get, data: {search_form_target: "form", turbo_frame:, turbo_action: "advance"}, **options.except(:data) do |form|
        form.hidden_field query_field
      end
    },
    stream_form: ->(url:, **options) {
      form_with url:, method: :get, data: {search_form_target: "form", turbo_frame:, turbo_stream: true}, **options.except(:data) do |form|
        form.hidden_field query_field
      end
    }
  }

  def initialize(search_name:, search_value:, search_placeholder:, turbo_frame: DEFAULT_FRAME, query_field: DEFAULT_QUERY_FIELD)
    @search_name = search_name
    @search_value = search_value
    @search_placeholder = search_placeholder
    @turbo_frame = turbo_frame
    @query_field = query_field
  end

  attr_reader :search_name, :search_value, :search_placeholder, :turbo_frame, :query_field
end
