class StoreRolloutsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, except: [:index]
  before_action :set_store_rollout, only: %i[start increase pause resume halt fully_release]
  before_action :ensure_moveable, only: %i[start increase pause resume halt fully_release]
  before_action :ensure_user_controlled_rollout, only: [:increase, :halt]
  before_action :ensure_automatic_rollout, only: [:pause]
  before_action :live_release!, only: %i[index]
  before_action :set_app, only: %i[index]
  around_action :set_time_zone

  def index
  end

  def start
    if (res = Action.start_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: res.error.message)}
    end
  end

  def increase
    if (res = Action.increase_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".increase.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".increase.failure", errors: res.error.message)}
    end
  end

  def pause
    if (res = Action.pause_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".pause.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".pause.failure", errors: res.error.message)}
    end
  end

  def resume
    if (res = Action.resume_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".resume.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".resume.failure", errors: res.error.message)}
    end
  end

  def halt
    if (res = Action.halt_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".halt.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".halt.failure", errors: res.error.message)}
    end
  end

  def fully_release
    if (res = Action.fully_release_the_store_rollout!(@store_rollout)).ok?
      redirect_back fallback_location: root_path, notice: t(".fully_release.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".fully_release.failure", errors: res.error.message)}
    end
  end

  private

  def set_store_rollout
    @store_rollout = StoreRollout.find(params[:id])
  end

  def set_app
    @app = @release.app
  end

  def ensure_automatic_rollout
    unless @store_rollout.automatic_rollout?
      redirect_back fallback_location: root_path, flash: {error: t(".rollout_not_automatic")}
    end
  end

  def ensure_moveable
    if @store_rollout.stale?
      redirect_back fallback_location: root_path, flash: {error: t(".rollout_not_moveable")}
    end
  end

  def ensure_user_controlled_rollout
    unless @store_rollout.controllable_rollout?
      redirect_back fallback_location: root_path, flash: {error: t(".rollout_not_controllable")}
    end
  end
end
