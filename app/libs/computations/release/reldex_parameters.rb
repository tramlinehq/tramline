class Services::ComputeReldexParameters
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  delegate :deployment_runs, :completed_at, :scheduled_at, :all_commits, :previous_release, :stability_commits, :duration, :all_hotfixes, to: :@release

  def call
    rollout_duration = 0
    stability_duration = 0
    rollout_fixes = 0
    rollout_changes = 0
    days_since_last_release = 0

    submitted_at = deployment_runs.map(&:submitted_at).compact.min
    rollout_started_at = deployment_runs.map(&:release_started_at).compact.min
    platform_store_versions = deployment_runs.reached_production.group_by(&:platform)
    max_store_versions = platform_store_versions.transform_values(&:size).values.max
    first_store_version = platform_store_versions.values.flatten.min_by(&:created_at)

    rollout_fixes = max_store_versions - 1 if max_store_versions.present?
    rollout_duration = ActiveSupport::Duration.build(completed_at - rollout_started_at).in_days if rollout_started_at.present?
    stability_duration = ActiveSupport::Duration.build(submitted_at - scheduled_at).in_days if submitted_at.present?
    days_since_last_release = ActiveSupport::Duration.build(completed_at - previous_release&.completed_at).in_days if previous_release.present?

    if rollout_fixes > 0
      base_commit = first_store_version.step_run.commit
      head_commit = all_commits.reorder(timestamp: :desc).first
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
