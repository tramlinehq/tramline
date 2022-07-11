class Releases::StepRunsController < SignedInApplicationController
  before_action :set_release

  def start
    step = @release.train.steps.friendly.find(params[:id])
    step_run = @release.step_runs.create(step:, scheduled_at: Time.current, status: "on_track", commit: @release.commits.last)
    step_run.automatons!
    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  def stop
    step = @release.train.steps.friendly.find(params[:id])
    step_run = @release.step_runs.find_by(step:, status: "on_track")
    step_run.update(status: "halted")
    redirect_back fallback_location: root_path, notice: "step halted"
  end

  private

  def set_release
    @release = Releases::Train::Run.joins(train: :app).where(apps: {organization: current_organization}).find(params[:release_id])
  end
end
