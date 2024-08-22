class Queries::ReldexParameters
  using RefinedEnumerable

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  delegate :completed_at,
    :scheduled_at,
    :all_commits,
    :previous_release,
    :stability_commits,
    :duration,
    :all_hotfixes,
    :production_store_submissions,
    :production_store_rollouts,
    to: :@release

  def call
    rollout_changes = 0
    days_since_last_release = 0

    platform_breakdowns = release_platform_runs.map { |prun| Queries::PlatformBreakdown.call(prun) }
    stability_duration = ActiveSupport::Duration.build(platform_breakdowns.map(&:stability_duration).max || 0)
    rollout_duration = ActiveSupport::Duration.build(platform_breakdowns.map { |r| r.production_releases.rollout_duration }.max || 0)
    rollout_fixes = platform_breakdowns.map { |r| r.production_releases.count - 1 }.max || 0
    days_since_last_release = ActiveSupport::Duration.build(completed_at - previous_release&.completed_at).in_days if previous_release.present?

    if rollout_fixes > 0
      base_commit = production_releases.first.commit
      head_commit = production_releases.last.commit
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