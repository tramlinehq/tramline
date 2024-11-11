class Queries::ReldexParameters
  using RefinedEnumerable

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  attr_reader :release
  delegate :completed_at,
    :scheduled_at,
    :all_commits,
    :previous_release,
    :stability_commits,
    :duration,
    :all_hotfixes,
    :production_store_submissions,
    :production_store_rollouts,
    :release_platform_runs,
    :production_releases,
    to: :release

  def call
    rollout_changes = 0
    days_since_last_release = 0

    platform_breakdowns = release_platform_runs.map { |run| Queries::PlatformBreakdown.call(run.id) }
    stability_duration = (platform_breakdowns.filter_map(&:stability_duration) || 0).min / 1.day
    rollout_duration = (platform_breakdowns.filter_map { |r| r.production_releases.rollout_duration } || 0).max / 1.day
    rollout_fixes = (platform_breakdowns.filter_map { |r| r.production_releases.count - 1 } || 0).max
    days_since_last_release = (completed_at - previous_release&.completed_at) / 1.day if previous_release.present?

    if rollout_fixes > 0
      # NOTE: production releases are pre-ordered in descending order
      base_commit = production_releases.last.commit
      head_commit = production_releases.first.commit
      rollout_changes = all_commits.between_commits(base_commit, head_commit).size
    end

    {
      hotfixes: all_hotfixes.size,
      rollout_fixes:,
      rollout_duration:,
      duration: duration.in_days,
      stability_duration:,
      stability_changes: stability_commits.count,
      days_since_last_release:,
      rollout_changes:
    }
  end
end
