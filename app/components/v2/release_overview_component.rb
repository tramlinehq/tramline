class V2::ReleaseOverviewComponent < V2::BaseComponent
  def initialize(release)
    @release = ReleasePresenter.new(release, self)
  end

  attr_reader :release
  delegate :internal_notes,
    :hotfixed_from,
    :team_stability_commits,
    :team_release_commits,
    :backmerge_pr_count,
    :backmerge_failure_count,
    :display_start_time,
    :display_end_time,
    :duration,
    :commit_count,
    :hotfix?,
    :hotfix_badge,
    :release_status,
    :release_branch,
    :tag_name,
    :continuous_backmerge?,
    :release_pilot_avatar,
    :release_pilot_name,
    :branch_url,
    :release_version,
    :automatic?,
    :tag_url,
    :active?,
    :reldex,
    :scheduled_badge,
    to: :release

  def show_release_unhealthy?
    release.show_health? && release.unhealthy?
  end

  def striped_header
    return "bg-diagonal-stripes-soft-gray" if release.upcoming?
    return "bg-diagonal-stripes-soft-red" if release.hotfix?
    "bg-diagonal-stripes-soft-blue" if release.ongoing?
  end

  def release_version_drift?
    release.release_platform_runs.flat_map(&:release_version).uniq.size > 1
  end

  def display_release_version(version)
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
