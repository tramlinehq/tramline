class V2::LiveRelease::OverviewComponent < V2::BaseReleaseComponent
  def initialize(release)
    @release = release
    @summary ||= Queries::ReleaseSummary.all(@release.id) if @release.finished?
    super(@release)
  end

  attr_reader :release
  delegate :internal_notes, to: :release

  def release_pilot_avatar
    user_avatar(@release.release_pilot.full_name, size: 22)
  end

  def commits_since_last
    @release.release_changelog&.normalized_commits
  end

  def team_stability_commits
    @summary[:team_stability_commits]
  end

  def team_release_commits
    @summary[:team_release_commits]
  end

  def overall_summary
    @summary[:overall]
  end

  def backmerge_summary
    "#{overall_summary.backmerge_pr_count} merged, #{overall_summary.backmerge_failure_count} failed"
  end

  def build_stability_chart
    {
      data: @release.stability_commits.count_by_team(current_organization).reject { |_, value| value.zero? },
      colors: current_organization.team_colors,
      type: "polar-area",
      value_format: "number",
      name: "team.build_stability",
      show_x_axis: false,
      show_y_axis: false
    }
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
end
