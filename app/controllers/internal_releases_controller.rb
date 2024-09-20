class InternalReleasesController < SignedInApplicationController
  include Tabbable

  def index
    live_release!
    @app = @release.app
  end

  def create
    commit_id = @release_platform_run.last_commit&.id

    if (result = Action.start_internal_release!(@release_platform_run, commit_id)).ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def default_params
    params.require(:pre_prod_release).permit(:build_id, :commit_id)
  end
end
