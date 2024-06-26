class WorkflowProcessors::Bitrise::WorkflowRun
  def initialize(integration, workflow_run, build_artifact_name_pattern)
    @integration = integration
    @workflow_run = workflow_run
    @build_artifact_name_pattern = build_artifact_name_pattern
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
    @integration.artifact_url(workflow_run[:slug], @build_artifact_name_pattern)
  end

  def started_at
    workflow_run[:triggered_at]
  end

  def finished_at
    workflow_run[:finished_at]
  end

  private

  attr_reader :workflow_run

  def status
    workflow_run[:status_text]
  end
end
