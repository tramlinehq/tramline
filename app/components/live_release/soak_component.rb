class LiveRelease::SoakComponent < BaseComponent
  def initialize(release, status: nil)
    @release = release
    @release_platform_runs = release.release_platform_runs
    @status = status
  end

  def success?
    @status == :success
  end

  def show_soak_actions?
    @release.soak_period_active?
  end

  def soak_start_time_display
    return nil unless @release.soak_started_at.present?
    @release.soak_started_at.in_time_zone(app_timezone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def soak_end_time_display
    return nil unless @release.soak_end_time.present?
    @release.soak_end_time.in_time_zone(app_timezone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def time_remaining_hours
    soak_seconds = @release.soak_time_remaining || 0
    soak_seconds / 3600.0
  end

  def time_remaining_display
    soak_seconds = (@release.soak_time_remaining || 0).to_i
    hours = soak_seconds / 3600
    minutes = (soak_seconds % 3600) / 60
    seconds = soak_seconds % 60
    sprintf("%02d:%02d:%02d", hours, minutes, seconds)
  end

  private

  def app_timezone
    @release.app.timezone
  end
end
