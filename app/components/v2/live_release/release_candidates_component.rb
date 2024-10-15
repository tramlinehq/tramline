# frozen_string_literal: true

class V2::LiveRelease::ReleaseCandidatesComponent < V2::BaseComponent
  def initialize(release)
    @release = release
  end

  attr_reader :release

  def configuration(release_platform_run)
    release_platform_run.conf.beta_release
  end

  def workflow_config(release_platform_run)
    release_platform_run.conf.release_candidate_workflow
  end

  def latest_beta_release(release_platform_run)
    release_platform_run.latest_beta_release
  end

  def previous_beta_releases(release_platform_run)
    release_platform_run.older_beta_releases
  end

  def builds(run)
    run.rc_builds.includes(:external_build)
  end
end
