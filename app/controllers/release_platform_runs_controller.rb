class ReleasePlatformRunsController < SignedInApplicationController
  before_action :require_write_access!, only: [:conclude]
  before_action :set_release_platform_run, only: [:conclude]

  def conclude
    result = Action.conclude_platform_run!(@release_platform_run)
    if result.ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  private

  def set_release_platform_run
    platform_run_id = params[:id] || params[:platform_run_id]

    if platform_run_id.blank?
      redirect_back fallback_location: root_path, flash: {error: t(".platform_run_required")} and return
    end

    @release_platform_run = ReleasePlatformRun.find(platform_run_id)
  end
end
