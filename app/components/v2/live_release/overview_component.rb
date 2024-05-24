class V2::LiveRelease::OverviewComponent < V2::BaseReleaseComponent
  def initialize(release)
    @release = release
    @summary ||= Queries::ReleaseSummary.all(@release.id) if @release.finished?
    super(@release)
  end

  attr_reader :release
  delegate :internal_notes, to: :release

  def commits_since_last
    @release.release_changelog&.normalized_commits
  end

  memoize def team_stability_commits
    return @summary[:team_stability_commits] if @summary.present?
    @release.stability_commits.count_by_team(current_organization)
  end

  memoize def team_release_commits
    return @summary[:team_release_commits] if @summary.present?
    @release.release_changelog&.commits_by_team
  end

  def overall_summary
    @summary[:overall]
  end

  def backmerge_summary
    "#{overall_summary.backmerge_pr_count} merged, #{overall_summary.backmerge_failure_count} failed"
  end

  def team_stability_chart
    {
      data: team_stability_commits&.reject { |_, value| value.zero? },
      colors: team_colors,
      type: "polar-area",
      value_format: "number",
      name: "release_summary.stability_contributors",
      show_x_axis: false,
      show_y_axis: false
    }
  end

  def team_release_chart
    {
      data: team_release_commits&.reject { |_, value| value.zero? },
      colors: team_colors,
      type: "polar-area",
      value_format: "number",
      name: "release_summary.release_contributors",
      show_x_axis: false,
      show_y_axis: false
    }
  end

  def final?
    @summary.present?
  end

  def changelog_present?
    @release.release_changelog.present?
  end
end
