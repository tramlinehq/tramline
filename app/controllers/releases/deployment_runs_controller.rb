class Releases::DeploymentRunsController < SignedInApplicationController
  before_action :set_deployment_run
  before_action :ensure_reviewable, only: [:submit_for_review]
  before_action :ensure_releasable, only: [:start_release]

  def submit_for_review
    Deployments::AppStoreConnect::Release.submit_for_review!(@deployment_run)

    if @deployment_run.failed?
      redirect_back fallback_location: root_path, flash: {error: "Failed to submit for review due to #{@deployment_run.display_attr(:failure_reason)}"}
    else
      redirect_back fallback_location: root_path, notice: "Submitted for review!"
    end
  end

  def start_release
    @deployment_run.start_release!

    if @deployment_run.failed?
      redirect_back fallback_location: root_path, flash: {error: "Failed to start the release due to #{@deployment_run.display_attr(:failure_reason)}"}
    else
      redirect_back fallback_location: root_path, notice: "The release has kicked-off!"
    end
  end

  def prepare_release
    Deployments::AppStoreConnect::Release.prepare_for_release!(@deployment_run, force: deployment_run_params[:force])

    if @deployment_run.failed? || @deployment_run.failed_prepare_release?
      redirect_back fallback_location: root_path, flash: {error: "Failed to prepare the release due to #{@deployment_run.display_attr(:failure_reason)}."}
    else
      redirect_back fallback_location: root_path, notice: "The new release has been prepared."
    end
  end

  private

  def deployment_run_params
    params.require(:deployment_run).permit(:force)
  end

  def ensure_reviewable
    unless @deployment_run.reviewable?
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot perform this operation. This deployment cannot be submitted for a review."}
    end
  end

  def ensure_releasable
    unless @deployment_run.releasable?
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot perform this operation. This deployment cannot be released."}
    end
  end

  def set_deployment_run
    @deployment_run = DeploymentRun.find_by(id: params[:id])
  end
end
