class StoreRolloutsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!
  before_action :set_store_rollout, only: %i[start increase pause resume halt fully_release]
  before_action :ensure_moveable, only: %i[start increase pause resume halt fully_release]
  before_action :ensure_user_controlled_rollout, only: [:increase, :halt]
  before_action :ensure_automatic_rollout, only: [:pause]

  def index
    live_release!
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

  def set_store_rollout
    @store_rollout = StoreRollout.find(params[:id])
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

  def ensure_moveable
    if @store_rollout.stale?
      redirect_back fallback_location: root_path, flash: {error: "The user cannot perform this action!"}
    end
  end
end
