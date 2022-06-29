class Releases::Releases::StepRunsController < ApplicationController
  def start
    release = Releases::Train::Run.find(params[:release_id])
    step = release.train.steps.friendly.find(params[:id])
    step_run = release.step_runs.create(step:, scheduled_at: Time.current, status: "on_track")
    step_run.automatons!
    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  def stop
    release = Releases::Train::Run.find(params[:release_id])
    step = release.train.steps.friendly.find(params[:id])
    step_run = release.step_runs.find_by(step:, status: "on_track")
    step_run.update(status: "halted")
    redirect_back fallback_location: root_path, notice: "step halted"
  end
end
