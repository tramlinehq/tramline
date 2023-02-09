class Queries::Helpers::Parameters
  def initialize
    @query = nil
    @limit = nil
    @offset = nil
  end

  attr_writer :query
  attr_reader :limit, :offset

  def paginate=(d)
    @limit, @offset = d.values_at(:limit, :offset)
  end

  def search_by(table_to_cols)
    return if @query.blank?

    table_to_cols.reduce(nil) do |acc, (table, cols)|
      cols.each do |col|
        acc =
          if acc.nil?
            col_matcher(table, col)
          else
            acc.or(col_matcher(table, col))
          end
      end

      acc
    end
  end

  def sort = nil

  private

  def col_matcher(arel_table, col)
    arel_table[col].matches("%#{@query}%")
  end
end
