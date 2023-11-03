class WorkflowProcessors::Github::WorkflowRun
  def initialize(workflow_run)
    @workflow_run = workflow_run
  end

  def in_progress?
    status == "in_progress" || status == "queued"
  end

  def successful?
    status == "completed" && conclusion == "success"
  end

  def failed?
    conclusion == "failure" || conclusion == "startup_failure"
  end

  def halted?
    status == "completed" && conclusion == "cancelled"
  end

  def artifacts_url
    workflow_run[:artifacts_url]
  end

  private

  attr_reader :workflow_run

  def status
    workflow_run[:status]
  end

  def conclusion
    workflow_run[:conclusion]
  end
end
