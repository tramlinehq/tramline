class Queries::Helpers::Parameters
  def initialize(q:)
    @query = q
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

  def paginate = nil

  def sort = nil

  private

  def col_matcher(arel_table, col)
    arel_table[col].matches("%#{@query}%")
  end
end
