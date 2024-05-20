class V2::LiveRelease::InternalBuildsComponent < V2::BaseComponent
  include Memery

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  attr_reader :release_platform_run

  memoize def latest_build
    release_platform_run.builds.last
  end

  memoize def previous_builds
    return unless release_platform_run.builds.size > 1
    release_platform_run.builds.where.not(id: latest_build.id)
  end

  memoize def step_runs
    review_step = release_platform_run.release_platform.steps.review.first

    release_platform_run.step_runs_for(review_step) || []
  end

  memoize def previous_step_runs
    return unless step_runs.size > 1
    step_runs.where.not(id: latest_step_run.id)
  end

  memoize def latest_step_run
    step_runs.last
  end
end
