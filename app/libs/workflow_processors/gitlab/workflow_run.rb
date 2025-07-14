class WorkflowProcessors::Gitlab::WorkflowRun
  def initialize(integration, workflow_payload)
    @integration = integration
    @workflow_payload = workflow_payload
  end

  def in_progress?
    %w[created waiting_for_resource preparing pending running].include?(status)
  end

  def successful?
    status == "success"
  end

  def failed?
    status == "failed"
  end

  def error?
    false
  end

  def halted?
    %w[skipped canceled canceling].include?(status)
  end

  def artifacts_url
    @integration.artifacts_url(job_id, workflow_payload[:artifacts])
  end

  def started_at
    workflow_payload[:started_at]
  end

  def finished_at
    workflow_payload[:finished_at]
  end

  private

  attr_reader :workflow_payload

  def status
    workflow_payload[:status]
  end

  def job_id
    workflow_payload[:id]
  end
end
