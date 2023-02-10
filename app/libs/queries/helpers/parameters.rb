class Queries::Helpers::Parameters
  UnpermittedFilterKey = Class.new(ArgumentError)
  DEFAULT_SORT_DIRECTION = "desc"

  def initialize
    @filters = {}
    @search_pattern = nil
    @limit = nil
    @offset = nil
    @sort_column = nil
    @sort_direction = DEFAULT_SORT_DIRECTION
  end

  attr_accessor :sort_column
  attr_reader :limit, :offset

  def add_sorting(col, dir)
    @sort_column = col
    @sort_direction = dir || DEFAULT_SORT_DIRECTION
  end

  def add_search_pattern(q)
    @search_pattern = q
  end

  def add_pagination(limit, offset)
    @limit, @offset = limit, offset
  end

  def add_filter(col, val)
    val = [val] unless val.is_a?(Array)
    @filters.merge!(col.to_sym => val)
  end

  def search_by(table_to_cols)
    return if @search_pattern.blank?

    table_to_cols.reduce(nil) do |acc, (table, cols)|
      cols.each do |col|
        acc =
          if acc.nil?
            col_matcher(table, col, @search_pattern)
          else
            acc.or(col_matcher(table, col, @search_pattern))
          end
      end

      acc
    end
  end

  def filter_by(allowed_cols)
    raise UnpermittedFilterKey unless @filters.keys.all? { |col| col.in? allowed_cols }

    @filters.reduce(nil) do |acc, (col, val)|
      if acc.nil?
        allowed_cols[col].in(val)
      else
        acc.or(allowed_cols[col].in(val))
      end
    end
  end

  def sort
    "#{@sort_column} #{@sort_direction}"
  end

  private

  def col_matcher(arel_table, col, term)
    arel_table[col].matches("%#{term}%")
  end
end
