class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :set_deployment_run
  delegate :transaction, to: :DeploymentRun

  def promote
    @deployment_run.promote!(promotion_params[:initial_rollout_percentage])
    redirect_back fallback_location: root_path, notice: "Promoted this deployment!"
  end

  private

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end

  def promotion_params
    params.require(:deployment_run).permit(:initial_rollout_percentage)
  end
end
