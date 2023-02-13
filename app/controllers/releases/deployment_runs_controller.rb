class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[promote]
  before_action :set_deployment_run
  delegate :transaction, to: :DeploymentRun

  def promote
    @deployment_run.assign_attributes(promotion_params)
    @deployment_run.promote!

    redirect_back fallback_location: root_path, notice: "Promoted this deployment!"
  end

  def rollout
    @deployment_run.update_rollout!

    redirect_back fallback_location: root_path, notice: "Updated the rollout for this deployment!"
  end

  private

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end

  def promotion_params
    params.require(:deployment_run).permit(:initial_rollout_percentage)
  end
end
