class StoreRolloutsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release
  before_action :set_release_platform
  before_action :set_release_platform_run
  before_action :ensure_user_controlled_rollout, only: [:increase, :halt]

  def increase
    if Coordinators::Signals.increase_the_store_rollout!(@rollout).ok?
      redirect_back fallback_location: root_path, notice: "Increased the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to increase the rollout. Please retry!"}
    end
  end

  def pause
    if Coordinators::Signals.pause_the_store_rollout!(@rollout).ok?
      redirect_back fallback_location: root_path, notice: "Paused the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to pause the rollout. Please retry!"}
    end
  end

  def resume
    if Coordinators::Signals.resume_the_store_rollout!(@rollout).ok?
      redirect_back fallback_location: root_path, notice: "Resumed the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to resume the rollout. Please retry!"}
    end
  end

  def halt
    if Coordinators::Signals.halt_the_store_rollout!(@rollout).ok?
      redirect_back fallback_location: root_path, notice: "Halted the rollout!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to halt the rollout. Please retry!"}
    end
  end

  def fully_release
    if Coordinators::Signals.fully_release_the_store_rollout!(@rollout).ok?
      redirect_back fallback_location: root_path, notice: "Fully released!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to fully release. Please retry!"}
    end
  end

  private

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def set_release_platform
    @release_platform = @release.release_platforms.friendly.find_by(platform: params[:platform_id])
  end

  def set_release_platform_run
    @release_platform_run = @release.release_platform_runs.find_by(release_platform: @release_platform)
  end

  def set_store_rollout
    @store_rollout = @release_platform_run.store_rollouts.find_by(id: params[:id])
  end

  def ensure_user_controlled_rollout
    unless @store_rollout.user_controlled_rollout?
      redirect_back fallback_location: root_path, flash: {error: "The user cannot perform this action!"}
    end
  end
end
