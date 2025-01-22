# frozen_string_literal: true

class LiveRelease::ReleaseCandidatesComponent < BaseComponent
  def initialize(release)
    @release = release
  end

  attr_reader :release

  def latest_beta_release(release_platform_run)
    release_platform_run.latest_beta_release
  end

  def previous_beta_releases(release_platform_run)
    release_platform_run.older_beta_releases
  end
end
