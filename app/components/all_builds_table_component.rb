class AllBuildsTableComponent < ViewComponent::Base
  include Pagy::Frontend
  include ApplicationHelper
  include LinkHelper
  include AssetsHelper
  include ReleasesHelper

  def initialize(builds:, paginator:, query_params:)
    @builds = builds
    @paginator = paginator
    @query_params = query_params
    @sort_column = query_params[:sort_column]
    @sort_direction = query_params[:sort_direction]
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
    image_tag("sort_indicator.svg", class: "inline-flex mx-2 align-baseline", width: 8)
  end

  def release_status(build)
    release_status_badge(build.release_status)
  end

  def release_platform(build)
    I18n.t("activerecord.values.release_platform.platform.#{build.platform}")
  end

  def external_release_status?
    builds.first.external_release_status.present?
  end

  def external_release_status(build)
    status_badge(build.external_release_status.titleize.humanize, %w[mx-1], :routine)
  end

  def submissions(build)
    tag.div do
      if build.submissions.blank?
        concat "–"
      else
        build.submissions.collect do |submission|
          concat tag.div submission.submission_info
        end
      end
    end
  end

  private

  def next_direction
    (@sort_direction == "asc") ? "desc" : "asc"
  end

  def path(column, direction)
    all_builds_app_path(@query_params.merge(sort_column: column, sort_direction: direction))
  end

  def turbo_data
    {turbo_frame: "all_builds"}
  end
end
