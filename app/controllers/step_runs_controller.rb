class StepRunsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[start retry_ci_workflow]
  before_action :set_release
  before_action :set_step, only: %i[start]
  before_action :set_step_run, only: %i[retry_ci_workflow sync_store_status]
  before_action :ensure_startable, only: %i[start]
  before_action :ensure_syncable, only: %i[sync_store_status]

  # FIXME: This action incorrectly consumes a step_id and not a step_run_id as the route suggests
  def start
    Triggers::StepRun.call(@step, @release.last_commit, @release)

    redirect_back fallback_location: root_path, notice: "Step successfully started"
  end

  def retry_ci_workflow
    @step_run.retry_ci!
    redirect_back fallback_location: root_path, notice: "CI workflow retried!"
  rescue
    error = "Failed to retry the CI workflow! Contact support if the issue persists."
    redirect_back fallback_location: root_path, flash: {error:}
  end

  def sync_store_status
    @step_run.sync_store_status!

    if @step_run.deployment_restarted?
      redirect_back fallback_location: root_path, notice: "Status resolved on the console UI, the release train will move forward."
    else
      redirect_back fallback_location: root_path, flash: {error: "Status remains unresolved on the console UI. Please make sure to submit the changes for review in a public track."}
    end
  rescue
    error = "Failed to sync the store status! Contact support if the issue persists."
    redirect_back fallback_location: root_path, flash: {error:}
  end

  private

  def set_step_run
    @step_run = @release.step_runs.find(params[:id])
  end

  def ensure_startable
    unless @release.manually_startable_step?(@step)
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot perform this operation. This step cannot be started."}
    end
  end

  def ensure_syncable
    unless @step_run.deployment_failed_with_sync_option?
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot perform this operation. This step cannot be started."}
    end
  end

  def set_release
    @release =
      ReleasePlatformRun
        .joins(release_platform: :app)
        .where(apps: {organization: current_organization})
        .find(params[:release_id])
  end

  def set_step
    @step = @release.release_platform.steps.friendly.find(params[:id])
  end

  def deployment_attributes
    params.require(:step_runs).permit(deployment_attributes: [:integration_id, :build_artifact_channel])
  end
end
