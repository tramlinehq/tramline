class WorkflowProcessors::Codemagic::WorkflowRun
  def initialize(integration, workflow_run, build_artifact_name_pattern)
    @integration = integration
    @workflow_run = workflow_run
    @build_artifact_name_pattern = build_artifact_name_pattern
  end

  def in_progress?
    %w[queued preparing fetching building testing publishing finishing].include?(status)
  end

  def successful?
    status == "finished"
  end

  def failed?
    %w[failed timeout].include?(status)
  end

  def error?
    status == "warning"
  end

  def halted?
    %w[canceled skipped].include?(status)
  end

  def artifacts_url
    @integration.artifact_url(@workflow_run["_id"], @build_artifact_name_pattern)
  end

  def started_at
    @workflow_run["startedAt"]
  end

  def finished_at
    @workflow_run["finishedAt"]
  end

  private

  def status
    @workflow_run["status"]
  end
end
