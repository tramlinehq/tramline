class StoreRolloutsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!
  before_action :set_release
  before_action :set_release_platform
  before_action :set_release_platform_run
  before_action :set_store_rollout, only: %i[start increase pause resume halt fully_release]
  before_action :ensure_user_controlled_rollout, only: [:increase, :halt]
  before_action :ensure_automatic_rollout, only: [:pause]
  before_action :set_live_release_tab_configuration, only: %i[edit_all]

  def edit_all
    @app = @release.app
  end

  def start
    if Action.start_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".start.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".start.failure")}
    end
  end

  def increase
    if Action.increase_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".increase.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".increase.failure")}
    end
  end

  def pause
    if Action.pause_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".pause.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".pause.failure")}
    end
  end

  def resume
    if Action.resume_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".resume.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".resume.failure")}
    end
  end

  def halt
    if Action.halt_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".halt.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".halt.failure")}
    end
  end

  def fully_release
    if Action.fully_release_the_store_rollout!(@store_rollout).ok?
      redirect_back fallback_location: root_path, notice: t(".fully_release.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".fully_release.failure")}
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
    @store_rollout = @release_platform_run.store_rollouts.find(params[:id])
  end

  def ensure_user_controlled_rollout
    unless @store_rollout.controllable_rollout?
      redirect_back fallback_location: root_path, flash: {error: "The user cannot perform this action!"}
    end
  end

  def ensure_automatic_rollout
    unless @store_rollout.automatic_rollout?
      redirect_back fallback_location: root_path, flash: {error: "The user cannot perform this action!"}
    end
  end
end
