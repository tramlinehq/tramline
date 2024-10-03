class V2::LiveRelease::OverviewComponent < V2::BaseComponent
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
    :continuous_backmerge?,
    :release_pilot_avatar,
    :release_pilot_name,
    :active?,
    to: :release

  def backmerge_summary
    "#{backmerge_pr_count} merged, #{backmerge_failure_count} failed"
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
      data: release.team_release_commits&.reject { |_, value| value.zero? },
      colors: team_colors,
      type: "polar-area",
      value_format: "number",
      name: "release_summary.release_contributors",
      show_x_axis: false,
      show_y_axis: false
    }
  end

  def hotfix_banner?
    hotfix? && release.all_commits.exists? && release.pre_prod_releases.none?
  end
end
