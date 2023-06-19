class DeploymentsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[start]
  before_action :set_release
  before_action :set_step_run
  before_action :set_deployment

  def start
    Triggers::Deployment.call(step_run: @step_run, deployment: @deployment)
    redirect_back fallback_location: root_path, notice: "Deployment successfully started!"
  end

  private

  def set_release
    @release =
      ReleasePlatformRun
        .joins(release_platform: :app)
        .where(apps: {organization: current_organization})
        .find_by(id: params[:release_id])
  end

  def set_step_run
    @step_run = @release.step_runs.find_by(id: params[:step_run_id])
  end

  def set_deployment
    @deployment = @step_run.deployments.find_by(id: params[:id])
  end
end
