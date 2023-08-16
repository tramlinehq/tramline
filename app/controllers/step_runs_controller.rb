class StepRunsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[start]
  before_action :set_release

  def start
    step = @release.release_platform.steps.friendly.find(params[:id])
    commit = @release.last_commit
    Triggers::StepRun.call(step, commit, @release)

    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  def retry_ci_workflow
    step_run = @release.step_runs.find(params[:id])
    step_run.retry_ci!

    redirect_back fallback_location: root_path, notice: "CI workflow retried!"
  end

  private

  def set_release
    @release =
      ReleasePlatformRun
        .joins(release_platform: :app)
        .where(apps: {organization: current_organization})
        .find(params[:release_id])
  end

  def deployment_attributes
    params.require(:step_runs).permit(deployment_attributes: [:integration_id, :build_artifact_channel])
  end
end
