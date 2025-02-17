# frozen_string_literal: true

class SearchBarComponent < BaseComponent
  FRAME = "search_bar_and_results"
  QUERY_FIELD = "search_pattern"

  renders_one :notice

  renders_one :search_form, ->(url) {
    form_with url: url, method: :get, data: {search_form_target: "form", turbo_frame: FRAME, turbo_action: "advance"} do |form|
      form.hidden_field QUERY_FIELD.to_sym
    end
  }

  def initialize(search_name:, search_value:, search_placeholder:)
    @search_name = search_name
    @search_value = search_value
    @search_placeholder = search_placeholder
  end

  attr_reader :search_name, :search_value, :search_placeholder
end
