class Queries::Events
  def self.all(**params)
    new(**params).all
  end

  FILTER_MAPPING = {
    android_platform: ReleasePlatform.arel_table[:platform],
    ios_platform: ReleasePlatform.arel_table[:platform]
  }

  def initialize(release:, params:)
    @release = release
    @params = params
  end

  attr_reader :release, :params

  def all
    Passport.where(stampable_id: stampable_ids).order(event_timestamp: :desc)
  end

  def stampable_ids
    release
      .release_platform_runs
      .joins(:release_platform)
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(FILTER_MAPPING)))
      .left_joins(step_runs: [:commit, [deployment_runs: :staged_rollout]])
      .pluck("commits.id, release_platform_runs.id, step_runs.id, deployment_runs.id, staged_rollouts.id")
      .flatten
      .uniq
      .compact
      .push(release.id)
  end
end
