class Releases::StepRunsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[start]
  before_action :set_release

  def start
    step = @release.train.steps.friendly.find(params[:id])
    commit = @release.last_commit
    Triggers::StepRun.call(step, commit)

    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  private

  def set_release
    @release =
      Releases::Train::Run
        .joins(train: :app)
        .where(apps: {organization: current_organization})
        .find(params[:release_id])
  end

  def deployment_attributes
    params.require(:releases_step_runs).permit(deployment_attributes: [:integration_id, :build_artifact_channel])
  end
end
