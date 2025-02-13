class BetaReleasesController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, except: %i[index]
  before_action :set_release_platform_run, only: %i[create]
  before_action :live_release!, only: %i[index]
  before_action :set_app, only: %i[index]
  around_action :set_time_zone

  def index
  end

  def create
    if (result = Action.start_beta_release!(@release_platform_run)).ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  private

  def default_params
    params.require(:pre_prod_release).permit(:build_id, :commit_id)
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:id])
  end

  def set_app
    @app = @release.app
    set_current_app
  end
end
