class V2::ReleaseOverviewComponent < V2::BaseReleaseComponent
  def initialize(release)
    @release = release
    super(@release)
  end

  attr_reader :release

  def show_release_unhealthy?
    current_user.release_monitoring? && release.show_health? && release.unhealthy?
  end

  def commit_count
    [release.applied_commits.size, 1].max - 1
  end

  def cross_platform?
    release.app.cross_platform?
  end

  def platform_runs
    @platform_runs ||=
      release.release_platform_runs.includes(step_runs: {deployment_runs: [:staged_rollout]})
  end

  def vcs_icon
    "integrations/logo_#{release.train.vcs_provider}.png"
  end

  def striped_header
    return "bg-diagonal-stripes-soft-gray" if release.upcoming?
    return "bg-diagonal-stripes-soft-red" if release.hotfix?
    "bg-diagonal-stripes-soft-blue" if release.ongoing?
  end

  def release_version_drift?
    release.release_platform_runs.flat_map(&:release_version).uniq.size > 1
  end

  def release_version(version)
    content_tag(:h1,
      version,
      class: "heading-2 text-main dark:text-white")
  end

  def android_release_version
    release.release_platform_runs.find { |r| r.platform == "android" }.release_version
  end

  def ios_release_version
    release.release_platform_runs.find { |r| r.platform == "ios" }.release_version
  end

  def grid_size
    return "grid-cols-2" if release.release_platform_runs.size > 1
    "grid-cols-1 w-2/3"
  end
end
