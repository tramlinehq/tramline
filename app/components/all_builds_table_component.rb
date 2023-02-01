class AllBuildsTableComponent < ViewComponent::Base
  def initialize(app:, path:, sort_column:, sort_direction:)
    @app = app
    @path = path
    @sort_column = sort_column
    @sort_direction = sort_direction
  end

  def all_builds
    @app.all_builds(column: @sort_column, direction: @sort_direction)
  end

  def sort_link(column:, label:)
    if column == @sort_column
      link_to(label, all_builds_app_path(sort_column: column, sort_direction: next_direction), data: turbo_data)
    else
      link_to(label, all_builds_app_path(sort_column: column, sort_direction: "asc"), data: turbo_data)
    end
  end

  private

  def next_direction
    (@sort_direction == "asc") ? "desc" : "asc"
  end

  def turbo_data
    { turbo_frame: "all_builds" }
  end
end
