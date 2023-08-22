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
      "Every #{train.repeat_duration.inspect} at #{train.kickoff_at.strftime("%I:%M%p (%Z)")}"
    else
      "No release schedule"
    end
  end

  def build_queue_config(train)
    if train.build_queue_enabled?
      "Applied every #{train.build_queue_wait_time.inspect} OR #{train.build_queue_size} commits"
    else
      "Applied with every new commit"
    end
  end
end
