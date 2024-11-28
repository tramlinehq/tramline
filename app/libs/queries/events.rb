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
    run_ids = release
      .release_platform_runs
      .joins(:release_platform)
      .where(ActiveRecord::Base.sanitize_sql_for_conditions(params.filter_by(FILTER_MAPPING)))
      .pluck(:id)

    results = GitHub::SQL.results <<~SQL.squish, release_id: release.id, run_ids: run_ids
      WITH "prod_release_data" AS (
        SELECT "production_releases".id
        FROM "production_releases"
        WHERE release_platform_run_id IN :run_ids
      ),
      "workflow_run_data" AS (
        SELECT "workflow_runs".id
        FROM "workflow_runs"
        WHERE release_platform_run_id IN :run_ids
      ),
      "store_submission_data" AS (
        SELECT "store_submissions".id
        FROM "store_submissions"
        WHERE release_platform_run_id IN :run_ids
      ),
      "store_rollout_data" AS (
        SELECT "store_rollouts".id
        FROM "store_rollouts"
        WHERE release_platform_run_id IN :run_ids
      ),
      "commit_data" AS (
        SELECT "commits".id
        FROM "commits"
        WHERE "commits"."release_id" = :release_id
      ),
      "pre_prod_release_data" AS (
        SELECT "pre_prod_releases".id
        FROM "pre_prod_releases"
        WHERE release_platform_run_id IN :run_ids
      )
      SELECT prod_release_data.id FROM prod_release_data
      UNION
      SELECT workflow_run_data.id FROM workflow_run_data
      UNION
      SELECT store_submission_data.id FROM store_submission_data
      UNION
      SELECT store_rollout_data.id FROM store_rollout_data
      UNION
      SELECT commit_data.id FROM commit_data
      UNION
      SELECT pre_prod_release_data.id FROM pre_prod_release_data
    SQL

    results
      .pluck("id")
      .concat(run_ids)
      .push(release.id)
      .uniq
      .compact
  end
end
