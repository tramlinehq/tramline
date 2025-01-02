class WorkflowRunsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_workflow_run, only: [:trigger, :retry, :fetch_status]

  def trigger
    if (result = Action.start_workflow_run!(@workflow_run)).ok?
      redirect_back fallback_location: internal_builds_path, notice: t(".success")
    else
      redirect_back fallback_location: internal_builds_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def retry
    if (result = Action.retry_workflow_run!(@workflow_run)).ok?
      redirect_back fallback_location: internal_builds_path, notice: t(".success")
    else
      redirect_back fallback_location: internal_builds_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def fetch_status
    if (result = Action.fetch_workflow_run_status!(@workflow_run)).ok?
      redirect_back fallback_location: internal_builds_path, notice: t(".success")
    else
      redirect_back fallback_location: internal_builds_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  private

  def set_workflow_run
    @workflow_run = WorkflowRun.find(params[:id])
  end

  def internal_builds_path
    release_internal_builds_path(@workflow_run.release)
  end
end
