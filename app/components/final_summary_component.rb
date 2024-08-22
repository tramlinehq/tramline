class FinalSummaryComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  attr_reader :release

  delegate :current_organization, :current_user, to: :helpers
  delegate :team_colors, to: :current_organization

  def initialize(release:)
    @release = release
  end

  def summary
    @summary ||= Queries::ReleaseSummary.all(release.id)
  end

  def duration_in_words(interval_in_seconds)
    return unless interval_in_seconds

    distance_of_time_in_words(Time.current, Time.current + interval_in_seconds.seconds, include_seconds: true)
  end

  def overall
    summary[:overall]
  end

  def pull_requests
    summary[:pull_requests]
  end

  def team_stability_commits
    summary[:team_stability_commits]
  end

  def team_release_commits
    summary[:team_release_commits]
  end

  def store_versions_by_platform
    summary[:store_versions].all.sort_by(&:platform).group_by(&:platform)
  end

  def step_summary_by_platform
    summary[:steps_summary].all.sort_by(&:platform).group_by(&:platform)
  end

  def reldex
    summary[:reldex]
  end

  def reldex?
    reldex.present?
  end

  def staged_rollouts(store_version)
    store_version.staged_rollouts.each do |sr|
      yield(sr[:rollout_percentage], sr[:timestamp])
    end
  end

  def tab_groups
    [
      "Overall",
      store_versions? ? "Store versions" : nil,
      "Step summary",
      pull_requests? ? "Pull requests" : nil,
      (current_organization.team_analysis_enabled? && teams_present?) ? "Team analysis" : nil
    ].compact
  end

  def store_versions?
    summary[:store_versions].all.present?
  end

  def pull_requests?
    pull_requests.present?
  end

  def teams_present?
    team_stability_commits.present? || team_release_commits.present?
  end

  def loaded?
    summary.present?
  end

  def backmerges?
    release.continuous_backmerge?
  end

  def hotfix?
    overall.is_hotfix
  end

  def hotfixes
    content_tag(:div, class: "inline-flex") do
      overall.hotfixes.each_with_index do |(release_version, release_link), i|
        concat link_to_external release_version, release_link, class: "underline ml-2"
      end
    end
  end

  def staged_rollouts?(store_version)
    store_version.staged_rollouts.present?
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
end
