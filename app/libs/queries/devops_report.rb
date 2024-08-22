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
      time_in_review: nil,
      hotfixes: nil,
      reldex_scores: reldex_scores,
      time_in_phases: nil,
      stability_contributors: release_stability_contributors,
      contributors: contributors,
      team_stability_contributors: team_stability_contributors,
      team_contributors: team_contributors
    }
  end

  LAST_RELEASES = 6
  LAST_TIME_PERIOD = 6

  memoize def duration(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { {duration: _1.first.duration.seconds} }
  end

  memoize def frequency(period = :month, format = "%b", last: LAST_TIME_PERIOD)
    finished_releases(last, hotfix: true)
      .reorder("")
      .group_by_period(period, :completed_at, last: last, current: true, format:)
      .count
      .transform_values { {releases: _1} }
  end

  memoize def reldex_scores(last: 10)
    return if train.release_index.blank?

    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { {reldex: _1.first.index_score&.value} }
  end

  memoize def release_stability_contributors(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.flat_map(&:all_commits).flat_map(&:author_email) }
      .transform_values { {contributors: _1.uniq.size} }
  end

  memoize def contributors(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { {contributors: _1.flat_map(&:release_changelog).compact.flat_map(&:unique_authors).size} }
  end

  memoize def team_stability_contributors(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { |releases| release_breakdown(releases[0]).team_stability_commits }
      .compact_blank
  end

  memoize def team_contributors(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { |releases| release_breakdown(releases[0]).team_release_commits }
      .compact_blank
  end

  # FIXME
  memoize def time_in_review(last: LAST_RELEASES)
    raise NotImplementedError
  end

  # FIXME
  memoize def hotfixes(last: LAST_RELEASES)
    raise NotImplementedError
  end

  # FIXME
  memoize def time_in_phases(last: LAST_RELEASES)
    raise NotImplementedError
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
          {release_platform_runs: [:release_platform]})

    return releases if hotfix
    releases.release
  end

  def cache_key
    "train/#{train.id}/queries/devops_report"
  end

  def release_breakdown(release)
    Queries::ReleaseBreakdown.new(release.id)
  end

  def thaw
    cache.delete(cache_key)
  end
end
