module TrainsHelper
  def steps_heading(release_platform)
    return release_platform.display_attr(:platform) + " Steps" if release_platform.app.cross_platform?
    "Steps"
  end

  def start_release_text(train, major: false)
    manual = train.automatic? ? "manual " : ""
    "Start #{manual}release #{train.next_release_version(major)}"
  end

  def release_schedule(train)
    if train.automatic?
      "Triggers a new release at #{train.kickoff_at.strftime("%I:%M%p")} every #{train.repeat_duration.in_days.to_i} day(s)"
    else
      "No release schedule"
    end
  end
end
