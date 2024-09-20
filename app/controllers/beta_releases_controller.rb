class BetaReleasesController < SignedInApplicationController
  include Tabbable
  before_action :require_write_access!, except: %i[index]
  before_action :set_release_platform_run, only: %i[create]

  def index
    live_release!
    @app = @release.app
  end

  def create
    build_id = nil
    commit_id = nil
    if @release_platform_run.carryover_build?
      # existing carryover build scenario
      latest_internal_release = @release_platform_run.latest_internal_release(finished: true)
      build_id = latest_internal_release.build.id
    else
      latest_commit = @release_platform_run.last_commit
      commit_id = latest_commit.commit_id
    end

    if (result = Action.start_beta_release!(@release_platform_run, build_id, commit_id)).ok?
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
    @release_platform_run = ReleasePlatformRun.find(params[:run_id])
  end
end
