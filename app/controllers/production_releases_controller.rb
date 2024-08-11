class ProductionReleasesController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release_platform_run

  def create
    build_id = default_params[:build_id]

    result = Action.start_new_production_release!(@release_platform_run, build_id)
    if result.ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      Rails.logger.error(result.error)
      redirect_back fallback_location: root_path, flash: {error: t(".failure")}
    end
  end

  def default_params
    params.require(:production_release).permit(:build_id)
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:run_id])
  end
end
