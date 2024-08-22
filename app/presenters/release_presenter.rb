class ReleasePresenter < SimpleDelegator
  include Memery
  using RefinedHash
  using RefinedInteger

  delegate :cross_platform?, to: :app
  delegate :automatic?, to: :train

  def initialize(release, view_context = nil)
    @view_context = view_context
    super(release)
  end

  def release_pilot_name
    release_pilot&.full_name || "Tramline"
  end

  def release_pilot_avatar
    h.user_avatar(release_pilot_name, size: 22)
  end

  def stop_release_warning
    message = ""
    message += "You have finished release to one of the platforms. " if partially_finished?
    message += "You have unmerged commits in this release branch. " if all_commits.size > 1
    message + "Are you sure you want to stop the release?"
  end

  memoize def breakdown
    Queries::ReleaseBreakdown.new(id)
  end

  memoize def platform_runs
    release_platform_runs.includes(:internal_builds,
      :internal_releases,
      :beta_releases,
      :production_releases,
      :rc_builds,
      :production_store_submissions,
      :production_store_rollouts)
  end

  memoize def display_release_version
    release_version
  end

  delegate :team_release_commits, :team_stability_commits, :reldex, to: :breakdown

  def hotfix_badge
    if hotfix?
      badge = V2::BadgeComponent.new(kind: :badge)
      badge.with_icon("band_aid.svg")
      badge.with_link("Hotfixed from #{hotfixed_from.release_version}", hotfixed_from.live_release_link)
      badge
    end
  end

  def scheduled_badge
    if is_automatic?
      badge = V2::BadgeComponent.new(text: "Automatic", kind: :badge)
      badge.with_icon("v2/robot.svg")
    else
      badge = V2::BadgeComponent.new(text: "Manual", kind: :badge)
      badge.with_icon("v2/person_standing.svg")
    end
    badge
  end

  def commit_count
    [applied_commits.size, 1].max - 1
  end

  def interval
    return start_time unless end_time
    "#{start_time} — #{end_time}"
  end

  def display_start_time
    h.time_format scheduled_at, with_time: false, with_year: true, dash_empty: true
  end

  def display_end_time
    h.time_format end_time, with_time: false, with_year: true, dash_empty: true
  end

  def duration
    return h.distance_of_time_in_words(scheduled_at, end_time) if end_time
    h.distance_of_time_in_words(scheduled_at, Time.current)
  end

  def h
    @view_context
  end
end
