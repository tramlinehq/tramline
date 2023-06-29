class CommitsController < SignedInApplicationController
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[apply]

  def apply
    commit = Commit.find(params[:id])
    commit.trigger_step_runs_for(release_platform_run)

    redirect_to live_release_app_train_releases_path(release.app, release.train),
      notice: "Steps have been triggered for the commit."
  end

  private

  def release_platform_run
    release.release_platform_runs.find { |run| run.platform == commit_params[:platform] }
  end

  def release
    Release.find(params[:release_id])
  end

  def commit_params
    params.require(:commit).permit(
      :platform
    )
  end
end
