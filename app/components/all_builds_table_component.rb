class AllBuildsTableComponent < BaseComponent
  include Pagy::Frontend
  include Memery

  renders_one :filter

  def initialize(builds:, paginator:, query_params:)
    @builds = builds
    @paginator = paginator
    @query_params = query_params
    @sort_column = query_params[:sort_column]
    @sort_direction = query_params[:sort_direction]
  end

  attr_reader :builds, :paginator

  def release_status(build)
    helpers.status_picker(ReleasePresenter::RELEASE_STATUS, build.release_status)
  end

  def submissions(build)
    tag.div do
      if build.submissions.blank?
        concat NOT_AVAILABLE
      else
        build.submissions.collect do |submission|
          concat tag.div submission.submission_info
        end
      end
    end
  end
end
