class Releases::StepRunsController < SignedInApplicationController
  before_action :set_release

  def start
    step = @release.train.steps.friendly.find(params[:id])
    commit = @release.last_commit
    Services::TriggerStepRun.call(step, commit)
    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  def stop
    step = @release.train.steps.friendly.find(params[:id])
    step_run = @release.step_runs.find_by(step:, status: "on_track")
    step_run.update(status: "halted")
    redirect_back fallback_location: root_path, notice: "step halted"
  end

  def promote
    step_run = Releases::Step::Run.find(params[:id])
    step_run.assign_attributes(promote_params)
    step_run.promote!
    redirect_back fallback_location: root_path, notice: "Promoted this build!"
  end

  private

  def promote_params
    params.require(:releases_step_run).permit(:initial_rollout_percentage)
  end

  def set_release
    @release = Releases::Train::Run.joins(train: :app).where(apps: {organization: current_organization}).find(params[:release_id])
  end
end
