module Filterable
  def set_query_sortables
    @sort_column = params[:sort_column].presence
    @sort_direction = params[:sort_direction].presence
  end

  def gen_query_filters(name, value)
    filter = {
      name => {
        filter_value: value,
        is_on: params.dig(:filters, name) == value
      }
    }

    @filters ||= {}
    @filters.deep_merge!({filters: filter})
  end

  def set_query_filters
    return if params[:filters].blank?

    params[:filters].keys.each do |name|
      filter_status = params[:filters][name].presence
      @query_params.add_filter(name, filter_status) if filter_status
    end
  end

  def set_query_params
    @query_params = Queries::Helpers::Parameters.new
  end

  def set_query_search_pattern
    return if params[:search_pattern].blank?
    @query_params.add_search_pattern(params[:search_pattern])
  end
end
