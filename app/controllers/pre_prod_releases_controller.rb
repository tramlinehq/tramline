class PreProdReleasesController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release_platform_run

  def create_beta
    # existing build scenario
    build_id = default_params[:build_id]
    commit_id = default_params[:commit_id]

    result = Action.start_beta_release!(@release_platform_run, build_id, commit_id)
    if result.ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      Rails.logger.error(result.error)
      redirect_back fallback_location: root_path, flash: {error: t(".failure")}
    end
  end

  def create_internal
    raise NotImplementedError
  end

  def default_params
    params.require(:pre_prod_release).permit(:build_id, :commit_id)
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:run_id])
  end
end