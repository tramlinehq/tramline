class LiveRelease::SoakComponent < BaseComponent
  def initialize(release, status: nil)
    @release = release
    @beta_soak = @release.beta_soak
    @release_platform_runs = release.release_platform_runs
    @status = status
  end

  attr_reader :beta_soak

  def show_soak_actions?
    return if beta_soak.nil?
    return if beta_soak.expired?
    beta_soak.ended_at.blank?
  end

  def soak_start_time
    beta_soak.started_at.in_time_zone(app_timezone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def soak_end_time
    return nil if beta_soak.end_time.blank?
    beta_soak.end_time.in_time_zone(app_timezone).strftime("%Y-%m-%d %H:%M %Z")
  end

  def time_remaining_hours
    soak_seconds = beta_soak.time_remaining || 0
    soak_seconds / 3600.0
  end

  def time_remaining
    soak_seconds = (beta_soak.time_remaining || 0).to_i
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
