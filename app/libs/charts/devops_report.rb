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
    # mobile devops
    # ---
    # release frequency (per month, area graph, each platform)
    # number of hotfixes across release (line graph, each platform)
    # release duration (line graph, each platform)
    # recovery time: time between last rollout and next hotfix (line graph, across platforms)

    # time spent in review in ios (across releases)
    # time in phases

    # operational efficiency
    # ---
    # automations run
    # ci workflow time (per step, area graph)
    # contributor list (count per release, area graph)
    {
      mobile_devops: {
        duration: {
          x_axis: duration.keys,
          series: [duration.values],
          legends: ["duration"],
          scope: "Last 5 releases",
          type: "line",
          title: "Release Duration",
          value_format: "time"
        },
        frequency: {
          x_axis: frequency.keys,
          series: [frequency.values],
          legends: ["frequency"],
          scope: "Last 6 months",
          type: "area",
          title: "Release Frequency",
          value_format: "number"
        },
        time_in_review: {
          x_axis: time_in_review.keys,
          series: [time_in_review.values],
          legends: ["time"],
          scope: "Last 5 releases",
          type: "area",
          title: "Time in Review",
          value_format: "time"
        },
        hotfixes: {
          x_axis: hotfixes.keys,
          series: [hotfixes.values.pluck("android"), hotfixes.values.pluck("ios")],
          legends: %w[android ios],
          scope: "Last 5 releases",
          type: "line",
          title: "Fixes during release",
          value_format: "number"
        },
        time_in_phases: {
          x_axis: time_in_phases.keys,
          series: time_in_phases.values.map(&:values),
          legends: time_in_phases.values.map(&:keys).first,
          scope: "Last 5 releases",
          type: "stacked-bar",
          title: "Duration across steps",
          value_format: "number"
        }
      },
      operational_efficiency: {
        contributors: {
          x_axis: contributors.keys,
          series: [contributors.values],
          legends: ["contributors"],
          scope: "Last 5 releases",
          type: "area",
          title: "Contributors",
          value_format: "number"
        },
        ci_workflow_time: {
          x_axis: contributors.keys,
          series: [contributors.values],
          legends: ["contributors"],
          scope: "Last 5 releases",
          type: "area",
          title: "CI Workflow Time",
          value_format: "time"
        },
        automations: {
          x_axis: contributors.keys,
          series: [contributors.values],
          legends: ["contributors"],
          scope: "Last 5 releases",
          type: "area",
          title: "Automations Run",
          value_format: "number"
        }
      }
    }
  end

  FREQUENCY_FORMAT = "%b %Y"
  FREQUENCY_PERIOD = :month

  memoize def duration(last: 5)
    # group by release (no platform split req.)
    train
      .releases
      .includes(:release_platform_runs)
      .limit(last)
      .finished
      .group_by(&:release_version)
      .sort_by { |version, _| version.to_semverish }.to_h
      .transform_values { _1.first.duration }
  end

  memoize def frequency(period = FREQUENCY_PERIOD, format = FREQUENCY_FORMAT, last: 6)
    # group by month (no platform split req.)
    train
      .releases
      .limit(last)
      .finished
      .reorder("")
      .group_by_period(period, :completed_at, last: last, current: true, format:)
      .size
  end

  memoize def contributors(last: 5)
    # group by release (no platform split req.)
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
      .includes(deployment_run: [:deployment, { step_run: { release_platform_run: [:release] } }])
      .where.not(reviewed_at: nil)
      .filter { _1.deployment_run.production_release_happened? }
      .group_by(&:build_version)
      .sort_by { |version, _| version.to_semverish }.to_h
      .transform_values { _1.flat_map(&:review_time) }
      .transform_values { _1.sum(&:seconds) / _1.size.to_f }
  end

  memoize def hotfixes(last: 5)
    # group by rel, and platform
    train
      .releases
      .limit(last)
      .finished
      .includes(step_runs: :deployment_runs)
      .flat_map(&:step_runs)
      .flat_map(&:deployment_runs)
      .filter { _1.production_release_happened? }
      .group_by(&:release_platform_run)
      .to_h { |platform_run, druns| [platform_run.release_version, { platform_run.platform => druns.size - 1 }] }
  end

  def recovery_time
    # group by rel
  end

  memoize def time_in_phases(last: 5)
    train
      .releases
      .limit(last)
      .finished
      .includes(:release_platform_runs, step_runs: :step)
      .flat_map(&:step_runs)
      .group_by(&:release_version)
      .sort_by { |version, _| version.to_semverish }.to_h
      .transform_values do |step_runs|
      step_runs
        .group_by(&:name)
        .transform_values { _1.pluck(:updated_at).max - _1.pluck(:scheduled_at).min }
    end
  end

  def ci_workflow_time
    raise NotImplementedError
  end

  def automations_run
    raise NotImplementedError
  end
end
