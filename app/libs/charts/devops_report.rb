class Charts::DevopsReport
  include Memery
  include Loggable
  using RefinedString

  def self.all(train)
    new(train).all
  end

  def initialize(train)
    @train = train
  end

  attr_reader :train

  def all
    {
      mobile_devops: {
        duration: {
          x_axis: duration.keys,
          series: [duration.values],
          legends: ["duration"],
          type: "area",
          value_format: "time",
          name: "devops.duration"
        },
        frequency: {
          x_axis: frequency.keys,
          series: [frequency.values],
          legends: ["releases"],
          type: "area",
          value_format: "number",
          name: "devops.frequency"
        },
        time_in_review: {
          x_axis: time_in_review.keys,
          series: [time_in_review.values],
          legends: ["time"],
          type: "area",
          value_format: "time",
          name: "devops.time_in_review"
        },
        hotfixes: {
          x_axis: hotfixes.keys,
          series: [hotfixes.values.pluck("android"), hotfixes.values.pluck("ios")],
          legends: %w[android ios],
          type: "area",
          value_format: "number",
          name: "devops.hotfixes"
        },
        time_in_phases: {
          x_axis: time_in_phases.keys,
          series: time_in_phases.values.map(&:values),
          legends: time_in_phases.values.map(&:keys).first,
          type: "stacked-bar",
          value_format: "time",
          name: "devops.time_in_phases"
        }
      },
      operational_efficiency: {
        contributors: {
          x_axis: contributors.keys,
          series: [contributors.values],
          legends: ["contributors"],
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
    train
      .releases
      .includes(:release_platform_runs)
      .limit(last)
      .finished
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.first.duration }
  end

  memoize def frequency(period = :month, format = "%b %y", last: LAST_TIME_PERIOD)
    train
      .releases
      .limit(last)
      .finished
      .reorder("")
      .group_by_period(period, :completed_at, last: last, current: true, format:)
      .size
  end

  memoize def contributors(last: LAST_RELEASES)
    train
      .releases
      .includes(:release_platform_runs, :all_commits)
      .limit(last)
      .group_by(&:release_version)
      .transform_values { _1.flat_map(&:all_commits).flat_map(&:author_email) }
      .transform_values { _1.uniq.size }
  end

  memoize def time_in_review
    # group by release (no platform split req.)
    train
      .external_releases
      .includes(deployment_run: [:deployment, {step_run: {release_platform_run: [:release]}}])
      .where.not(reviewed_at: nil)
      .filter { _1.deployment_run.production_release_happened? }
      .group_by(&:build_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values { _1.flat_map(&:review_time) }
      .transform_values { _1.sum(&:seconds) / _1.size.to_f }
  end

  memoize def hotfixes(last: LAST_RELEASES)
    train
      .releases
      .limit(last)
      .finished
      .includes(step_runs: :deployment_runs)
      .flat_map(&:step_runs)
      .flat_map(&:deployment_runs)
      .filter { _1.production_release_happened? }
      .group_by(&:release_platform_run)
      .to_h { |platform_run, druns| [platform_run.release_version, {platform_run.platform => druns.size - 1}] }
  end

  def recovery_time
    # group by rel
    # recovery time: time between last rollout and next hotfix (line graph, across platforms)
  end

  memoize def time_in_phases(last: LAST_RELEASES)
    train
      .releases
      .limit(last)
      .finished
      .includes(:release_platform_runs, step_runs: :step)
      .flat_map(&:step_runs)
      .group_by(&:release_version)
      .sort_by { |v, _| v.to_semverish }.to_h
      .transform_values do |step_runs|
      step_runs
        .group_by(&:name)
        .transform_values { _1.pluck(:updated_at).max - _1.pluck(:scheduled_at).min }
    end
  end

  def ci_workflow_time
    # ci workflow time (per step, area graph)
    raise NotImplementedError
  end

  def automations_run
    raise NotImplementedError
  end
end
