class WorkflowRunsController < SignedInApplicationController
  before_action :set_workflow_run, only: [:trigger, :retry]

  def trigger
    @workflow_run.initiate_trigger!
    redirect_back fallback_location: internal_builds_path, notice: t(".trigger.success")
  end

  def retry
    @workflow_run.retry!
    redirect_back fallback_location: internal_builds_path, notice: t(".retry.success")
  rescue
    redirect_back fallback_location: internal_builds_path, flash: {error: t(".retry.error")}
  end

  private

  def set_workflow_run
    @workflow_run = WorkflowRun.find(params[:id])
  end

  def internal_builds_path
    internal_builds_release_path(@workflow_run.release)
  end
end
