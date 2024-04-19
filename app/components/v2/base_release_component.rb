# This is a base component for other release-related components
# Note: this doesn't actually render anything
class V2::BaseReleaseComponent < V2::BaseComponent
  include Memery
  using RefinedHash
  using RefinedInteger

  def initialize(release)
    @release = release
  end

  delegate :release_branch, :tag_name, to: :release

  memoize def status
    return ReleasesHelper::SHOW_RELEASE_STATUS.fetch(:upcoming) if @release.upcoming?
    ReleasesHelper::SHOW_RELEASE_STATUS.fetch(@release.status.to_sym)
  end

  def hotfix_badge
    if @release.hotfix?
      hotfixed_from = @release.hotfixed_from

      badge = V2::BadgeComponent.new
      badge.with_icon("band_aid.svg")
      badge.with_link("Hotfixed from #{hotfixed_from.release_version}", hotfixed_from.live_release_link)
      badge
    end
  end

  def scheduled_badge
    if @release.is_automatic?
      badge = V2::BadgeComponent.new("Automatic")
      badge.with_icon("v2/robot.svg")
    else
      badge = V2::BadgeComponent.new("Manual")
      badge.with_icon("v2/person_standing.svg")
    end
    badge
  end

  def automatic?
    @release.train.automatic?
  end

  def step_summary(platform)
    @step_summary ||= Queries::ReleaseSummary::StepsSummary.from_release(@release).all
    platform_steps = @step_summary.select { |step| step.platform_raw == platform }

    initial_data = {started_at: nil, ended_at: nil, builds_created_count: 0, duration: "--"}
    initial_phase_data = {review: initial_data.dup, release: initial_data.dup}

    result = platform_steps.each_with_object(initial_phase_data) do |step, acc|
      acc[step.phase.to_sym][:started_at] = [step.started_at, acc[step.phase.to_sym][:started_at]].compact.min
      acc[step.phase.to_sym][:ended_at] = [step.ended_at, acc[step.phase.to_sym][:ended_at]].compact.max
      acc[step.phase.to_sym][:builds_created_count] += step.builds_created_count || 0
    end

    [:review, :release].each do |phase|
      next unless result[phase][:started_at]
      duration = distance_of_time_in_words(result[phase][:started_at], result[phase][:ended_at] || Time.current)
      result[phase][:duration] = duration
    end

    result
  end

  memoize def release_summary
    Queries::ReleaseSummary.all(@release.id)
  end

  memoize def release_version
    @release.release_version
  end

  memoize def branch
    @release.branch_name
  end

  memoize def interval
    return start_time unless @release.end_time
    "#{start_time} — #{end_time}"
  end

  memoize def start_time
    time_format @release.scheduled_at, with_time: false, with_year: true, dash_empty: true
  end

  memoize def end_time
    time_format @release.end_time, with_time: false, with_year: true, dash_empty: true
  end

  memoize def duration
    return distance_of_time_in_words(@release.scheduled_at, @release.end_time) if @release.end_time
    distance_of_time_in_words(@release.scheduled_at, Time.current)
  end
end
