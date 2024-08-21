class Queries::ReleaseBreakdown
  using RefinedEnumerable
  include Memery
  include Loggable

  def self.warm(release_id)
    new(release_id).warm
  end

  def self.call(release_id, from_cache: true)
    new(release_id, from_cache:).call
  end

  def initialize(release_id, from_cache: true)
    @release_id = release_id
    @from_cache = from_cache
  end

  def warm
    cache.write(cache_key, data)
  rescue => e
    elog(e)
  end

  def call
    return cache.fetch(cache_key) if @from_cache
    data
  end

  Platform = Data.define(:name, :stability_duration, :internal_builds_count, :release_candidates_count, :production_releases)
  ProductionRelease = Data.define(:count, :submission_duration, :rollout_duration)

  attr_reader :release_id
  delegate :cache, to: Rails

  memoize def release
    Release
      .where(id: release_id)
      .includes(:all_commits,
        :pull_requests,
        train: [:release_platforms],
        release_platform_runs: [
          :internal_builds,
          :internal_releases,
          :beta_releases,
          :rc_builds,
          :production_store_submissions,
          :production_store_rollouts
        ])
      .sole
  end

  def runs
    release.release_platform_runs
  end

  def platforms
    release.release_platforms.pluck(:platform).product([nil]).to_h
  end

  delegate :active?, to: :release

  def data
    runs.each_with_object(platforms) do |run, acc|
      prod_releases = run.production_releases
      rollouts = run.production_store_rollouts
      prod_submissions = run.production_store_submissions
      internal_builds = run.internal_builds
      beta_releases = run.beta_releases
      internal_releases = run.internal_releases
      rc_builds = run.rc_builds

      stability_s_ts = internal_releases.vmin_by(:created_at) || beta_releases.vmin_by(:created_at)
      stability_e_ts = prod_releases.vmin_by(:created_at) || (active? ? Time.current : rc_builds.vmax_by(:updated_at))

      prod_submission_s_ts = prod_submissions.vmax_by(:submitted_at)
      prod_submission_e_ts = prod_submissions.vmin_by(:prepared_at)
      prod_submission_time = safe_subtract(prod_submission_e_ts, prod_submission_s_ts)

      prod_rollout_s_ts = rollouts.vmin_by(:created_at)
      prod_rollout_e_ts = rollouts.vmax_by(:completed_at) || prod_releases.vmax_by(:updated_at)
      prod_rollout_time = safe_subtract(prod_rollout_e_ts, prod_rollout_s_ts)

      acc[run.platform] = Platform.new(
        name: run.platform,
        stability_duration: safe_subtract(stability_e_ts, stability_s_ts),
        internal_builds_count: internal_builds.size,
        release_candidates_count: rc_builds.size,
        production_releases: ProductionRelease.new(prod_releases.size, prod_submission_time, prod_rollout_time)
      )
    end
  end

  def thaw
    cache.delete(cache_key)
  end

  def cache_key
    "release/#{release_id}/breakdown"
  end

  def safe_subtract(time1, time2)
    time1.to_time.to_i - time2.to_time.to_i if time1.present? && time2.present?
  end
end
