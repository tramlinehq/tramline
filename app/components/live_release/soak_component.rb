class LiveRelease::SoakComponent < BaseComponent
  def initialize(release, status: nil, current_user: nil)
    @release = release
    @release_platform_runs = release.release_platform_runs
    @status = status
    @current_user = current_user
  end

  def success?
    @status == :success
  end

  def show_soak_actions?
    @release.soak_period_active? && user_is_release_pilot?
  end

  def show_pilot_only_message?
    @release.soak_period_active? && !user_is_release_pilot?
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
    soak_seconds = @release.soak_time_remaining || 0
    Time.at(soak_seconds).utc.strftime("%H:%M:%S")
  end

  private

  def user_is_release_pilot?
    @current_user == @release.release_pilot
  end

  def app_timezone
    @release.app.timezone
  end
end
