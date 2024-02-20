class V2::BaseReleaseComponent < V2::BaseComponent
  include Memery

  def initialize(release)
    @release = release
  end

  memoize def status
    ReleasesHelper::SHOW_RELEASE_STATUS.fetch(@release.status.to_sym)
  end

  memoize def hotfix_badge
    if @release.hotfix?
      hotfixed_from = @release.hotfixed_from
      hotfixed_from_version = hotfixed_from.release_version.to_s
      # hotfixed_from_link = hotfixed_from.live_release_link
      {
        text: "Hotfixed from #{hotfixed_from_version}",
        icon: "band_aid.svg"
      }
    end
  end

  memoize def interval
    return start_time unless @release.completed_at
    "#{start_time} — #{end_time}"
  end

  memoize def start_time
    time_format @release.scheduled_at, with_time: false, with_year: true, dash_empty: true
  end

  memoize def end_time
    time_format @release.completed_at, with_time: false, with_year: true, dash_empty: true
  end

  memoize def duration
    return "–" unless @release.completed_at
    distance_of_time_in_words(@release.scheduled_at, @release.completed_at)
  end

  delegate :release_branch, to: :release

  def release_tag
    release.tag_name
  end
end
