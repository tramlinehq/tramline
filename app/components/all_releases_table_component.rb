class AllReleasesTableComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include ApplicationHelper
  include LinkHelper

  def initialize(releases:, paginator:, query_params:)
    @releases = releases
    @paginator = paginator
    @query_params = query_params
  end

  private

  attr_reader :releases, :paginator, :query_params

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

  def rows
    releases.map do |release|
      [
        status_cell(release.release_status),
        commit_messages_cell(release.all_commits, release.pull_requests),
        created_cell(release.created_at),
      ]
    end
  end

  def status_cell(status)
    render StatusBadgeComponent.new(status: status)
  end

  def commit_messages_cell(commits, pull_requests)
    commits.map { |commit| commit["message"] }.join(", ") + pull_requests.map { |pr| pr["title"] }.join(", ")
  end

  def created_cell(timestamp)
    format_timestamp(timestamp)
  end
  
  def sort_indicator
    image_tag("sort_indicator.svg", class: "inline-flex mx-2 align-baseline", width: 8)
  end

  def path(column, direction)
    search_app_path(@query_params.merge(sort_column: column, sort_direction: direction))
  end

  def turbo_data
    {turbo_frame: "all_releases"}
  end
end 
