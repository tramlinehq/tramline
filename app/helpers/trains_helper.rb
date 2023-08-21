module TrainsHelper
  def steps_heading(release_platform)
    return release_platform.display_attr(:platform) + " Steps" if release_platform.app.cross_platform?
    "Steps"
  end

  def start_release_text(train, major: false)
    text = train.automatic? ? "Manually start " : "Start "
    text += major ? "major " : "minor "
    text += "release "
    text + train.next_version(major)
  end

  def release_schedule(train)
    if train.automatic?
      "Every #{train.repeat_duration.in_days.to_i} day(s) at #{train.kickoff_at.strftime("%I:%M%p (%Z)")}"
    else
      "No release schedule"
    end
  end
end
