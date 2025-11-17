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

  private

  def user_is_release_pilot?
    @current_user == @release.release_pilot
  end
end
