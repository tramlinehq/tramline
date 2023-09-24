class FinalSummaryComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  attr_reader :release

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

  def store_versions_by_platform
    summary[:store_versions].all.group_by(&:platform)
  end

  def step_summary_by_platform
    summary[:steps_summary].all.group_by(&:platform)
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
      pull_requests? ? "Pull requests" : nil
    ].compact
  end

  def store_versions?
    summary[:store_versions].all.present?
  end

  def pull_requests?
    pull_requests.present?
  end

  def loaded?
    summary.present?
  end

  def backmerges?
    release.continuous_backmerge?
  end

  def staged_rollouts?(store_version)
    store_version.staged_rollouts.present?
  end
end
