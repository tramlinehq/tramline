class ProductionReleasesController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release_platform_run, only: %i[create]
  before_action :set_prod_release, only: %i[changes_since_previous]
  before_action :set_app, only: %i[changes_since_previous]

  def create
    build_id = default_params[:build_id]

    result = Action.start_new_production_release!(@release_platform_run, build_id)
    if result.ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def changes_since_previous
    @commits = @prod_release.commits_since_previous
  end

  def default_params
    params.require(:production_release).permit(:build_id)
  end

  def set_release_platform_run
    @release_platform_run = ReleasePlatformRun.find(params[:run_id])
  end

  def set_prod_release
    @prod_release = ProductionRelease.includes(release_platform_run: [release_platform: :app]).find(params[:id])
  end

  def set_app
    @app = @prod_release.release_platform_run.app
  end
end
