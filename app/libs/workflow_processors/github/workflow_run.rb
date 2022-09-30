class WorkflowProcessors::Github::WorkflowRun
  def initialize(workflow_run_attrs)
    @workflow_run_attrs = workflow_run_attrs
  end

  def in_progress?
    status == "in_progress" || status == "queued"
  end

  def successful?
    status == "completed" && conclusion == "success"
  end

  def failed?
    conclusion == "failure"
  end

  def halted?
    status == "completed" && conclusion == "cancelled"
  end

  def artifacts_url
    workflow_run_attrs[:artifacts_url]
  end

  private

  attr_reader :workflow_run_attrs

  def status
    workflow_run_attrs[:status]
  end

  def conclusion
    workflow_run_attrs[:conclusion]
  end
end
