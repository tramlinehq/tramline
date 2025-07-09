class WorkflowProcessors::Gitlab::WorkflowRun
  def initialize(workflow_payload)
    @workflow_payload = workflow_payload
  end

  def in_progress?
    %w[created waiting_for_resource preparing pending running].include?(status)
  end

  def successful?
    status == "success"
  end

  def failed?
    %w[failed canceled].include?(status)
  end

  def error?
    false
  end

  def halted?
    %w[skipped manual].include?(status)
  end

  def artifacts_url
    true
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
end
