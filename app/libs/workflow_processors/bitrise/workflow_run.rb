class WorkflowProcessors::Bitrise::WorkflowRun
  def initialize(integration, workflow_run_attrs)
    @integration = integration
    @workflow_run_attrs = workflow_run_attrs
  end

  def in_progress?
    status == "in-progress" || status == "on-hold"
  end

  def successful?
    status == "success"
  end

  def failed?
    status == "failed"
  end

  def halted?
    status == "aborted"
  end

  def artifacts_url
    @integration.artifact_url(workflow_run_attrs[:slug])
  end

  private

  attr_reader :workflow_run_attrs

  def status
    workflow_run_attrs[:status_text]
  end
end
