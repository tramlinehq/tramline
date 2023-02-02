class AllBuildsTableComponent < ViewComponent::Base
  include Pagy::Frontend
  include ApplicationHelper

  def initialize(builds:, paginator:, path:, sort_column:, sort_direction:)
    @builds = builds
    @paginator = paginator
    @path = path
    @sort_column = sort_column
    @sort_direction = sort_direction
  end

  attr_reader :builds, :paginator

  def sort_link(column:, label:)
    if column == @sort_column
      link_to(path(column, next_direction), data: turbo_data) do
        concat tag.span(label)
        concat sort_indicator
      end
    else
      link_to(path(column, "asc"), data: turbo_data) do
        concat tag.span(label)
        concat sort_indicator
      end
    end
  end

  def sort_indicator
    image_tag("sort_indicator.svg", class: "inline-flex mx-2", width: 8)
  end

  private

  def next_direction
    (@sort_direction == "asc") ? "desc" : "asc"
  end

  def path(column, direction)
    all_builds_app_path(sort_column: column, sort_direction: direction)
  end

  def turbo_data
    {turbo_frame: "all_builds"}
  end
end
