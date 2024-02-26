# This is a base component for other release-related components
# Note that this doesn't actually render anything
class V2::BaseReleaseComponent < V2::BaseComponent
  include Memery
  using RefinedHash
  using RefinedInteger

  def initialize(release)
    @release = release
  end

  memoize def status
    ReleasesHelper::SHOW_RELEASE_STATUS.fetch(@release.status.to_sym)
  end

  # TODO: UI: just render the badge component?
  def hotfix_badge
    if @release.hotfix?
      hotfixed_from = @release.hotfixed_from

      badge = V2::BadgeComponent.new
      badge.with_icon("band_aid.svg")
      badge.with_link("Hotfixed from #{hotfixed_from.release_version}", hotfixed_from.live_release_link)
      badge
    end
  end

  def step_summary(platform)
    @step_summary ||= Queries::ReleaseSummary::StepsSummary.from_release(@release).all
    platform_steps = @step_summary.select { |step| step.platform_raw == platform }

    initial_data = {review: {duration: 0, builds_created_count: 0}, release: {duration: 0, builds_created_count: 0}}
    result = platform_steps.each_with_object(initial_data) do |step, acc|
      acc[step.phase.to_sym][:duration] += step.duration || 0
      acc[step.phase.to_sym][:builds_created_count] += step.builds_created_count || 0
    end

    result[:review] =
      result[:review].update_key(:duration) do |duration|
        duration.humanize_duration || "-"
      end

    result[:release] =
      result[:release].update_key(:duration) do |duration|
        duration.humanize_duration || "-"
      end

    result
  end

  memoize def release_version
    @release.release_version
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

  delegate :release_branch, to: :release

  def release_tag
    release.tag_name
  end
end
