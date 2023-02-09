module Filterable
  extend ActiveSupport::Concern

  included do
    helper_method :get_query_filter

    def gen_query_filters(name, value)
      filter = {
        name => {
          filter_value: {name => value},
          is_on: params.dig(:filters, name) == value
        }
      }

      @filters ||= {}
      @filters.deep_merge!(filter)
    end

    def get_query_filter(name)
      {filters: @filters.dig(name, :filter_value)}
    end

    def set_query_helpers
      set_query_params
      set_query_search_pattern
      set_query_filters
      set_query_sortables
    end

    def set_query_pagination(total_count)
      @pagy = Pagy.new(count: total_count, page: params[:page])
      @query_params.add_pagination(@pagy.items, @pagy.offset)
    end

    def set_query_sortables
      @sort_column = params[:sort_column].presence
      @sort_direction = params[:sort_direction].presence
    end

    def set_query_filters
      return if params[:filters].blank?

      params[:filters].keys.each do |name|
        filter_status = params[:filters][name].presence
        @query_params.add_filter(name, filter_status) if filter_status
      end
    end

    def set_query_search_pattern
      return if params[:search_pattern].blank?
      @query_params.add_search_pattern(params[:search_pattern])
    end

    def set_query_params
      @query_params = Queries::Helpers::Parameters.new
    end
  end
end
