class PreProdReleaseController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release_platform_run

  def create_beta
    Coordinators::Signals.start_beta_release!(@release_platform_run, pre_prod_release_params[:build_id])
  end

  def create_internal
    raise NotImplementedError
  end

  def pre_prod_release_params
    params.require(:pre_prod_release).permit(:build_id)
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:release_platform_run_id])
  end
end
