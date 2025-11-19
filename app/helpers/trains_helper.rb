module TrainsHelper
  def release_schedule(train)
    if train.automatic?
      duration = train.repeat_duration.inspect
      time = train.kickoff_time.strftime("%I:%M%p")
      timezone = train.app.timezone
      "Runs every #{duration} at #{time} (#{timezone})"
    else
      "No release schedule"
    end
  end
end
