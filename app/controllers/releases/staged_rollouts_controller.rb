class Releases::StagedRolloutsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[increase halt]
  before_action :set_deployment_run
  before_action :set_staged_rollout

  def increase
    @staged_rollout.move_to_next_stage!

    if @staged_rollout.failed?
      redirect_back fallback_location: root_path, flash: {error: "Failed to increase the rollout. Please retry!"}
    else
      redirect_back fallback_location: root_path, notice: "Increased the rollout!"
    end
  end

  def halt
    @staged_rollout.halt!
    redirect_back fallback_location: root_path, notice: "Halted the staged rollout!"
  end

  private

  def set_staged_rollout
    @staged_rollout = @deployment_run.staged_rollout
  end

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:deployment_run_id])
  end
end
