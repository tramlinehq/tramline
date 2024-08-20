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
    ids = release.is_v2? ? v2_stampable_ids : stampable_ids
    Passport.where(stampable_id: ids).order(event_timestamp: :desc)
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

  def v2_stampable_ids
    release
      .release_platform_runs
      .joins(:release_platform)
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(FILTER_MAPPING)))
      .left_joins(:production_releases, :workflow_runs, :store_submissions, :store_rollouts, pre_prod_releases: :commit)
      .pluck("release_platform_runs.id, pre_prod_releases.id, production_releases.id, workflow_runs.id, store_submissions.id, store_rollouts.id, commits.id")
      .flatten
      .uniq
      .compact
      .push(release.id)
  end
end
