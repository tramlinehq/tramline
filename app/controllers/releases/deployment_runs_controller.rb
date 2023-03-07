class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :set_deployment_run
  before_action :ensure_submittable

  def submit_for_review
    if Deployments::AppStoreConnect::Release.submit_for_review!(@deployment_run)
      redirect_back fallback_location: root_path, notice: "Submitted for review!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to submit for review!"}
    end
  end

  private

  def ensure_submittable
    unless @deployment_run.reviewable?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. This deployment cannot be submitted for a review."}
    end
  end

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end
end
