class V2::ReleaseOverviewComponent < V2::BaseReleaseComponent
  def initialize(release)
    @release = release
    super(@release)
  end

  attr_reader :release

  def show_release_unhealthy?
    current_user.release_monitoring? && release.show_health? && release.unhealthy?
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
      class: "heading-2 text-main dark:text-white font-normal")
  end

  def android_release_version
    release.release_platform_runs.find { |r| r.platform == "android" }.release_version
  end

  def ios_release_version
    release.release_platform_runs.find { |r| r.platform == "ios" }.release_version
  end
end
