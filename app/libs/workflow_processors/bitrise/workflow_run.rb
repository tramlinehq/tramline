class WorkflowProcessors::Bitrise::WorkflowRun
  def initialize(integration, workflow_run, step_run)
    @integration = integration
    @workflow_run = workflow_run
    @step_run = step_run
  end

  def in_progress?
    status == "in-progress" || status == "on-hold"
  end

  def successful?
    status == "success"
  end

  def failed?
    status == "failed" || status == "error"
  end

  def halted?
    status == "aborted"
  end

  def artifacts_url
    @integration.artifact_url(workflow_run[:slug], @step_run.build_artifact_name_pattern)
  end

  private

  attr_reader :workflow_run

  def status
    workflow_run[:status_text]
  end
end
