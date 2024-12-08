module ReleasesHelper
  SHOW_RELEASE_STATUS = {
    finished: ["Completed", :success],
    stopped: ["Stopped", :inert],
    created: ["Running", :ongoing],
    on_track: ["Running", :ongoing],
    upcoming: ["Upcoming", :inert],
    post_release: ["Finalizing", :neutral],
    post_release_started: ["Finalizing", :neutral],
    post_release_failed: ["Finalizing", :neutral],
    partially_finished: ["Partially Finished", :ongoing],
    stopped_after_partial_finish: ["Stopped & Partially Finished", :inert]
  }

  def release_status_badge(status)
    status, styles = SHOW_RELEASE_STATUS.fetch(status.to_sym)
    status_badge(status, styles)
  end
end
