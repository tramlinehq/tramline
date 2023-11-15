module TrainsHelper
  def steps_heading(release_platform)
    return release_platform.display_attr(:platform) + " Steps" if release_platform.app.cross_platform?
    "Steps"
  end

  def start_release_text(train, major: false)
    text = train.automatic? ? "Manually start " : "Start "
    text += major ? "major " : "minor "
    text += "release "
    text + train.next_version(major_only: major)
  end

  def start_upcoming_release_text(ongoing_release, major: false)
    text = "Prepare next "
    text += major ? "major " : "minor "
    text += "release "
    text + ongoing_release.next_version(major_only: major)
  end

  def release_schedule(train)
    if train.automatic?
      date = time_format(train.kickoff_at, with_year: true, with_time: false)
      duration = train.repeat_duration.inspect
      time = train.kickoff_at.strftime("%I:%M%p (%Z)")
      "Kickoff at #{date} – runs every #{duration} at #{time}"
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

  BUILD_QUEUE_ENABLED_LABEL = "Build Queue enabled"
  BUILD_QUEUE_DISABLED_LABEL = "Build Queue disabled"

  def build_queue_label(train)
    if train.build_queue_enabled?
      BUILD_QUEUE_ENABLED_LABEL
    else
      BUILD_QUEUE_DISABLED_LABEL
    end
  end

  def backmerge_text(train)
    if train.continuous_backmerge?
      "Changes on the release branch will be merged <b>continuously</b> to the working branch."
    else
      "Changes on the release branch will be merged to the working branch <b>at the end</b> of the release."
    end
  end
end
