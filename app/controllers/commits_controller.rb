class CommitsController < SignedInApplicationController
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[apply]
  before_action :set_release, only: %i[apply]
  before_action :set_commit, only: %i[apply]
  before_action :set_release_platform_run, only: %i[apply]
  before_action :ensure_release_platform_run, only: %i[apply]

  def apply
    @release_platform_run.with_lock do
      locked_release_error and return unless @release_platform_run.on_track?
      already_triggered_error and return if @release_platform_run.commit_applied?(@commit)
      @commit.trigger_step_runs_for(@release_platform_run, force: true)
    end

    redirect_to current_release_path, notice: "Steps have been triggered for the commit."
  end

  private

  def already_triggered_error
    redirect_to current_release_path, flash: {error: "Cannot re-apply a commit to a release!"}
  end

  def locked_release_error
    redirect_to current_release_path, flash: {error: "Cannot apply a commit to a locked release."}
  end

  def ensure_release_platform_run
    if @release_platform_run.blank?
      redirect_to current_release_path, flash: {error: "Could not find the release!"}
    end
  end

  def set_release_platform_run
    @release_platform_run = @release.release_platform_runs.find_by(id: commit_params[:release_platform_run_id])
  end

  def set_commit
    @commit = Commit.find(params[:id])
  end

  def set_release
    @release = Release.find(params[:release_id])
  end

  def commit_params
    params.require(:commit).permit(
      :release_platform_run_id
    )
  end

  def current_release_path
    release_path(@release)
  end
end
