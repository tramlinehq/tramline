module ScheduledReleasesHelper
  def scheduled_release_badge(scheduled_release)
    if scheduled_release.is_success?
      status_badge("success", :success)
    elsif !scheduled_release.pending?
      status_badge("skipped", :neutral)
    else
      status_badge("scheduled", :ongoing)
    end
  end

  def scheduled_release_text(scheduled_release)
    time_format(scheduled_release.scheduled_at)
  end
end
