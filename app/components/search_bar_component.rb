# frozen_string_literal: true

class SearchBarComponent < BaseComponent
  FRAME = "search_bar_and_results"
  QUERY_FIELD = "search_pattern"

  renders_one :text_field, ->(name, value, placeholder) {
    text_field_tag name, value, {
      placeholder: placeholder.presence || "Search",
      class: "form-input inline-flex",
      autocomplete: "off",
      data: { search_form_target: "searchInput", action: "input->search-form#search" }
    }
  }

  renders_one :clear_search, -> {
    link_to "clear search",
            "#",
            title: "clear search",
            class: "inline-flex underline relative hover:cursor-pointer text-xs top-2 right-0 ml-1",
            data: { action: "search-form#clear" }
  }

  renders_one :search_form, ->(url) {
    form_with url: url, method: :get, data: { search_form_target: "form", turbo_frame: FRAME, turbo_action: "advance" } do |form|
      form.hidden_field QUERY_FIELD.to_sym
    end
  }
end
