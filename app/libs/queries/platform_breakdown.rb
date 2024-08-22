class Queries::PlatformBreakdown
  using RefinedEnumerable
  include Loggable

  def self.warm(release_platform_run_id)
    new(release_platform_run_id).warm
  end

  def self.call(release_platform_run_id)
    new(release_platform_run_id).call
  end

  def initialize(release_platform_run_id)
    @release_platform_run_id = release_platform_run_id
    @run = release_platform_run
  end

  def warm
    cache.write(cache_key, data)
  rescue => e
    elog(e)
  end

  def call
    cache.fetch(cache_key) { data }
  end

  Platform = Data.define(:name, :stability_duration, :internal_builds_count, :release_candidates_count, :production_releases)
  ProductionRelease = Data.define(:count, :submission_duration, :rollout_duration)

  attr_reader :run
  delegate :cache, to: Rails

  def release_platform_run
    ReleasePlatformRun
      .where(id: @release_platform_run_id)
      .includes(
        :release_platform,
        :internal_builds,
        :internal_releases,
        :beta_releases,
        :production_releases,
        :rc_builds,
        :production_store_rollouts
      )
      .sole
  end

  def platforms
    runs.release_platforms.pluck(:platform).product([nil]).to_h
  end

  def data
    prod_releases = run.production_releases
    rollouts = run.production_store_rollouts
    internal_builds = run.internal_builds
    beta_releases = run.beta_releases
    internal_releases = run.internal_releases
    rc_builds = run.rc_builds

    stability_s_ts = internal_releases.vmin_by(:created_at) || beta_releases.vmin_by(:created_at)
    stability_e_ts = prod_releases.vmin_by(:created_at) || (run.active? ? Time.current : rc_builds.vmax_by(:updated_at))

    prod_submission_s_ts = prod_releases.vmin_by(:created_at)
    prod_submission_e_ts = rollouts.vmin_by(:created_at)
    prod_submission_time = safe_subtract(prod_submission_e_ts, prod_submission_s_ts)

    prod_rollout_s_ts = rollouts.vmin_by(:created_at)
    prod_rollout_e_ts = rollouts.vmax_by(:completed_at) || prod_releases.vmax_by(:updated_at)
    prod_rollout_time = safe_subtract(prod_rollout_e_ts, prod_rollout_s_ts)

    Platform.new(
      name: run.platform,
      stability_duration: safe_subtract(stability_e_ts, stability_s_ts),
      internal_builds_count: internal_builds.size,
      release_candidates_count: rc_builds.size,
      production_releases: ProductionRelease.new(prod_releases.size, prod_submission_time, prod_rollout_time)
    )
  end

  def thaw
    cache.delete(cache_key)
  end

  def cache_key
    "platform_run/#{@release_platform_run_id}/breakdown"
  end

  def safe_subtract(time1, time2)
    time1.to_time.to_i - time2.to_time.to_i if time1.present? && time2.present?
  end
end
