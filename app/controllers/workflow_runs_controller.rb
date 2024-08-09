class WorkflowRunsController < SignedInApplicationController
  before_action :set_workflow_run, only: [:trigger, :retry]

  def trigger
    if (result = Coordinators::Signals.start_workflow_run!(@workflow_run)).ok?
      redirect_back fallback_location: internal_builds_path, notice: t(".trigger.success")
    else
      redirect_back fallback_location: internal_builds_path, flash: {error: t(".trigger.failure", errors: result.error.message)}
    end
  end

  def retry
    if (result = Coordinators::Signals.retry_workflow_run!(@workflow_run)).ok?
      redirect_back fallback_location: internal_builds_path, notice: t(".retry.success")
    else
      redirect_back fallback_location: internal_builds_path, flash: {error: t(".retry.failure", errors: result.error.message)}
    end
  end

  private

  def set_workflow_run
    @workflow_run = WorkflowRun.find(params[:id])
  end

  def internal_builds_path
    internal_builds_release_path(@workflow_run.release)
  end
end
