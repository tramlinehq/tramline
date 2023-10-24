class Charts::DevopsReport
  include Memery
  using RefinedString

  def self.warm(train) = new(train).warm

  def self.all(train) = new(train).all

  def initialize(train) = @train = train

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
      mobile_devops: {
        duration: {
          data: duration,
          type: "area",
          value_format: "time",
          name: "devops.duration"
        },
        frequency: {
          data: frequency,
          type: "area",
          value_format: "number",
          name: "devops.frequency"
        },
        time_in_review: {
          data: time_in_review,
          type: "area",
          value_format: "time",
          name: "devops.time_in_review"
        },
        hotfixes: {
          data: hotfixes,
          type: "area",
          value_format: "number",
          name: "devops.hotfixes"
        },
        time_in_phases: {
          data: time_in_phases,
          stacked: true,
          type: "stacked-bar",
          value_format: "time",
          name: "devops.time_in_phases"
        }
      },
      operational_efficiency: {
        contributors: {
          data: contributors,
          type: "line",
          value_format: "number",
          name: "operational_efficiency.contributors"
        }
      }
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

  memoize def frequency(period = :month, format = "%b %y", last: LAST_TIME_PERIOD)
    finished_releases(last)
      .reorder("")
      .group_by_period(period, :completed_at, last: last, current: true, format:)
      .count
      .transform_values { {releases: _1} }
  end

  memoize def contributors(last: LAST_RELEASES)
    finished_releases(last)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.flat_map(&:all_commits).flat_map(&:author_email) }
      .transform_values { {contributors: _1.uniq.size} }
  end

  memoize def time_in_review
    train
      .external_releases
      .includes(deployment_run: [:deployment, {step_run: {release_platform_run: [:release]}}])
      .where.not(reviewed_at: nil)
      .filter { _1.deployment_run.production_release_happened? }
      .group_by(&:build_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.flat_map(&:review_time) }
      .transform_values { {time: _1.sum(&:seconds) / _1.size.to_f} }
  end

  memoize def hotfixes(last: LAST_RELEASES)
    by_version =
      finished_releases(last)
        .flat_map(&:step_runs)
        .flat_map(&:deployment_runs)
        .filter { _1.production_release_happened? }
        .group_by { _1.release.release_version }
        .sort_by { |v, _| v.to_semverish }.to_h

    by_version.transform_values do |runs|
      runs.group_by(&:platform).transform_values { |d| d.size.pred }
    end
  end

  def recovery_time
    # group by rel
    # recovery time: time between last rollout and next hotfix (line graph, across platforms)
    raise NotImplementedError
  end

  memoize def time_in_phases(last: LAST_RELEASES)
    by_version =
      finished_releases(last)
        .flat_map(&:step_runs)
        .group_by(&:release_version)
        .sort_by { |v, _| v.to_semverish }.to_h

    by_version.transform_values do |runs|
      runs.group_by(&:platform).transform_values do |by_platform|
        by_platform.group_by(&:name).transform_values do
          _1.pluck(:updated_at).max - _1.pluck(:scheduled_at).min
        end
      end
    end
  end

  def ci_workflow_time
    # ci workflow time (per step, area graph)
    raise NotImplementedError
  end

  def automations_run
    raise NotImplementedError
  end

  private

  attr_reader :train
  delegate :cache, to: Rails

  memoize def finished_releases(n)
    train
      .releases
      .limit(n)
      .finished
      .includes(:release_platform_runs, :all_commits, step_runs: [:deployment_runs, :step])
  end

  def cache_key
    "train/#{train.id}/devops_report"
  end

  def thaw
    cache.delete(cache_key)
  end
end
