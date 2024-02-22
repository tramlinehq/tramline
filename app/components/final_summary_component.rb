class FinalSummaryComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  attr_reader :release

  delegate :current_organization, to: :helpers
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
      teams_present? ? "Team analysis" : nil
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
    {data: Accounts::Team::sample_team_commits.sort_by(&:last).reverse.to_h,
     colors: Accounts::Team::SAMPLE_TEAM_COLOR,
     type: "polar-area",
     value_format: "number",
     name: "Stability Contribution",
     title: "Stability Contribution",
     scope: "Fixes (commits) during the release",
     help_text: "",
     show_x_axis: false,
     show_y_axis: false}
  end

  def team_release_chart
    {data: Accounts::Team::sample_team_commits.sort_by(&:last).reverse.to_h,
     colors: Accounts::Team::SAMPLE_TEAM_COLOR,
     type: "polar-area",
     value_format: "number",
     name: "Release Contribution",
     title: "Release Contribution",
     scope: "Work done (commits) for the release",
     help_text: "",
     show_x_axis: false,
     show_y_axis: false}
  end
end
