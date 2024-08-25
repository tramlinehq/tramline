# This is a base component for other release-related components
# Note: this doesn't actually render anything
class V2::BaseReleaseComponent < V2::BaseComponent
  include Memery
  using RefinedHash
  using RefinedInteger

  RELEASE_STATUS = {
    finished: ["Completed", :success],
    stopped: ["Stopped", :failure],
    created: ["Running", :ongoing],
    on_track: ["Running", :ongoing],
    upcoming: ["Upcoming", :inert],
    post_release: ["Finalizing", :neutral],
    post_release_started: ["Finalizing", :neutral],
    post_release_failed: ["Finalizing", :neutral],
    partially_finished: ["Partially Finished", :ongoing],
    stopped_after_partial_finish: ["Stopped & Partially Finished", :failure]
  }

  def initialize(release)
    @release = release
  end

  delegate :release_branch, :tag_name, to: :@release

  memoize def release_pilot_name
    @release.release_pilot&.full_name || "Tramline"
  end

  def release_pilot_avatar
    user_avatar(release_pilot_name, size: 22)
  end

  def stop_release_warning
    message = ""
    message += "You have finished release to one of the platforms. " if @release.partially_finished?
    message += "You have unmerged commits in this release branch. " if @release.all_commits.size > 1
    message + "Are you sure you want to stop the release?"
  end

  # TODO: [V2] I don't think this is being used in the v2 stuff, consider removing - kit
  memoize def status
    return RELEASE_STATUS.fetch(:upcoming) if @release.upcoming?
    RELEASE_STATUS.fetch(@release.status.to_sym)
  end

  def human_slug
    @release.slug
  end

  def platform_runs
    @platform_runs ||=
      @release.release_platform_runs.includes(step_runs: {deployment_runs: [:staged_rollout]})
  end

  def cross_platform?
    @release.app.cross_platform?
  end

  memoize def hotfixed_from
    @release.hotfixed_from
  end

  def hotfix_badge
    if @release.hotfix?
      badge = V2::BadgeComponent.new(kind: :badge)
      badge.with_icon("band_aid.svg")
      badge.with_link("Hotfixed from #{hotfixed_from.release_version}", hotfixed_from.live_release_link)
      badge
    end
  end

  def scheduled_badge
    if @release.is_automatic?
      badge = V2::BadgeComponent.new(text: "Automatic", kind: :badge)
      badge.with_icon("v2/robot.svg")
    else
      badge = V2::BadgeComponent.new(text: "Manual", kind: :badge)
      badge.with_icon("v2/person_standing.svg")
    end
    badge
  end

  def automatic?
    @release.train.automatic?
  end

  def backmerges?
    @release.continuous_backmerge?
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

  def commit_count
    [@release.applied_commits.size, 1].max - 1
  end

  memoize def release_version
    @release.release_version
  end

  def interval
    return start_time unless @release.end_time
    "#{start_time} — #{end_time}"
  end

  def start_time
    time_format @release.scheduled_at, with_time: false, with_year: true, dash_empty: true
  end

  def end_time
    time_format @release.end_time, with_time: false, with_year: true, dash_empty: true
  end

  def duration
    return distance_of_time_in_words(@release.scheduled_at, @release.end_time) if @release.end_time
    distance_of_time_in_words(@release.scheduled_at, Time.current)
  end
end
