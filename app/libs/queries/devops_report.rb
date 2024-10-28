class Queries::DevopsReport
  include Memery
  include Loggable
  using RefinedString

  def self.warm(train) = new(train).warm

  def self.all(train) = new(train).all

  def initialize(train)
    @train = train
    @organization = train.organization
  end

  attr_reader :train, :organization

  def warm
    cache.write(cache_key, report)
  rescue => e
    elog(e)
  end

  def all
    cache.fetch(cache_key)
  end

  def report
    {
      refreshed_at: Time.current,
      duration: duration,
      frequency: frequency,
      time_in_review: time_in_review,
      patch_fixes: patch_fixes,
      hotfixes: hotfixes,
      reldex_scores: reldex_scores,
      time_in_phases: time_in_phases,
      stability_contributors: release_stability_contributors,
      contributors: contributors,
      team_stability_contributors: team_stability_contributors,
      team_contributors: team_contributors
    }
  end

  LAST_RELEASES = 6
  LAST_TIME_PERIOD = 6

  memoize def duration(last: LAST_RELEASES)
    releases_by_version(last).transform_values { {duration: _1.first.duration.seconds} }
  end

  memoize def frequency(period = :month, format = "%b", last: LAST_TIME_PERIOD)
    finished_releases(last)
      .reorder("")
      .group_by_period(period, :completed_at, last: last, current: true, format:)
      .count
      .transform_values { {releases: _1} }
  end

  memoize def reldex_scores(last: 10)
    return if train.release_index.blank?
    releases_by_version(last).transform_values { {reldex: _1.first.index_score&.value} }
  end

  memoize def release_stability_contributors(last: LAST_RELEASES)
    releases_by_version(last)
      .transform_values { _1.flat_map(&:all_commits).flat_map(&:author_email) }
      .transform_values { {contributors: _1.uniq.size} }
  end

  memoize def contributors(last: LAST_RELEASES)
    releases_by_version(last).transform_values do
      {contributors: _1.flat_map(&:release_changelog).compact.flat_map(&:unique_authors).size}
    end
  end

  memoize def team_stability_contributors(last: LAST_RELEASES)
    releases_by_version(last)
      .transform_values { |releases| release_breakdown(releases[0]).team_stability_commits }
      .compact_blank
  end

  memoize def team_contributors(last: LAST_RELEASES)
    releases_by_version(last)
      .transform_values { |releases| release_breakdown(releases[0]).team_release_commits }
      .compact_blank
  end

  memoize def time_in_review(last: LAST_RELEASES)
    # NOTE: we are looking for last n approved iOS store submissions not last n releases, hence the buffer
    finished_releases(last + 10, hotfix: true)
      .flat_map { |release| release.release_platform_runs.find(&:ios?) }
      .compact
      .flat_map(&:production_store_submissions)
      .filter(&:approved?)
      .sort_by(&:created_at)
      .last(last)
      .group_by(&:version_name)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.flat_map(&:review_time) }
      .transform_values { {time: _1.sum(&:seconds) / _1.size.to_f} }
  end

  memoize def patch_fixes(last: LAST_RELEASES)
    releases_by_version(last).transform_values do |releases|
      platform_runs = releases.flat_map(&:release_platform_runs)
      platform_runs.group_by(&:platform).transform_values { |run| [run[0].production_releases.size.pred, 0].max }
    end
  end

  memoize def hotfixes(last: LAST_RELEASES)
    releases_by_version(last).transform_values do |releases|
      hotfixes = releases.flat_map(&:all_hotfixes)
      if hotfixes.any?
        hotfixes.flat_map(&:release_platform_runs).group_by(&:platform).transform_values(&:size)
      else
        releases.flat_map(&:release_platform_runs).group_by(&:platform).transform_values { 0 }
      end
    end
  end

  memoize def time_in_phases(last: LAST_RELEASES)
    releases_by_version(last).transform_values do |releases|
      platform_runs = releases.flat_map(&:release_platform_runs)
      platform_runs.group_by(&:platform).transform_values do |run|
        breakdown = platform_breakdown(run[0].id)
        {
          stability_time: breakdown.stability_duration,
          submission_time: breakdown.production_releases.submission_duration,
          rollout_time: breakdown.production_releases.rollout_duration
        }
      end
    end
  end

  def ci_workflow_time
    raise NotImplementedError
  end

  def automations_run
    raise NotImplementedError
  end

  def recovery_time
    # group by rel
    # recovery time: time between last rollout and next hotfix (line graph, across platforms)
    raise NotImplementedError
  end

  private

  delegate :cache, to: Rails

  memoize def finished_releases(n, hotfix: false)
    releases =
      train
        .releases
        .limit(n)
        .finished
        .reorder("completed_at DESC")
        .includes(:release_changelog,
          :all_commits,
          {release_platform_runs: [:release_platform, :production_store_submissions]})

    return releases if hotfix
    releases.release
  end

  memoize def releases_by_version(n, hotfix: false)
    finished_releases(n, hotfix: hotfix)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
  end

  def cache_key
    "train/#{train.id}/queries/devops_report"
  end

  def release_breakdown(release)
    Queries::ReleaseBreakdown.new(release.id)
  end

  def platform_breakdown(release_platform_run_id)
    Queries::PlatformBreakdown.call(release_platform_run_id)
  end

  def thaw
    cache.delete(cache_key)
  end
end
