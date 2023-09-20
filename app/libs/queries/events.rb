class Queries::Events
  include Memery

  def self.all(**params)
    new(**params).all
  end

  def initialize(release:, params:)
    @release = release
    @params = params
  end

  attr_reader :release, :params

  def all
    if params.filters[:ios]&.include? "ios"
      passports(platform_ids("ios"))
    elsif params.filters[:android]&.include? "android"
      passports(platform_ids("android"))
    else
      passports(all_ids)
    end
  end

  def all_ids
    release
      .release_platform_runs
      .left_joins(step_runs: [:commit, [deployment_runs: :staged_rollout]])
      .pluck("commits.id, release_platform_runs.id, step_runs.id, deployment_runs.id, staged_rollouts.id")
      .flatten
      .uniq
      .compact
      .push(release.id)
  end

  def platform_ids(platform)
    release
      .release_platform_runs
      .joins(:release_platform).where(release_platform: {platform: platform})
      .left_joins(step_runs: [:commit, [deployment_runs: :staged_rollout]])
      .pluck("commits.id, release_platform_runs.id, step_runs.id, deployment_runs.id, staged_rollouts.id")
      .flatten
      .uniq
      .compact
      .push(release.id)
  end

  def passports(ids)
    Passport.where(stampable_id: ids).order(event_timestamp: :desc)
  end
end
