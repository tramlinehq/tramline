class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[promote]
  before_action :set_deployment_run

  def promote
    @deployment_run.promote!
    redirect_back fallback_location: root_path, notice: "Promoted this deployment!"
  end

  private

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end
end
