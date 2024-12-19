module TrainsHelper
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
end
