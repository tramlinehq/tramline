class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :set_deployment_run
  before_action :ensure_submittable, only: [:submit_for_review]
  before_action :ensure_rolloutable, only: [:fully_release]

  def submit_for_review
    if Deployments::AppStoreConnect::Release.submit_for_review!(@deployment_run)
      redirect_back fallback_location: root_path, notice: "Submitted for review!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to submit for review!"}
    end
  end

  def fully_release
    if Deployments::AppStoreConnect::Release.complete_phased_release!(@deployment_run)
      redirect_back fallback_location: root_path, notice: "Released to all users!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Failed to release to all users!"}
    end
  end

  private

  def ensure_submittable
    unless @deployment_run.reviewable?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. This deployment cannot be submitted for a review."}
    end
  end

  def ensure_rolloutable
    unless @deployment_run.rolloutable?
      redirect_back fallback_location: root_path, flash: {error: "Cannot perform this operation. This deployment cannot be rolled out."}
    end
  end

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end
end
