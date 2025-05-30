class WorkflowProcessors::Bitbucket::WorkflowRun
  def initialize(workflow_payload)
    @workflow_payload = workflow_payload
  end

  def in_progress?
    !pipeline_completed?
  end

  def successful?
    return false unless pipeline_completed?
    status == "SUCCESSFUL" && status_type == "pipeline_state_completed_successful"
  end

  def failed?
    # if it still appears like its in progress, but one of the stages is halted, then it's a failure
    return true if pipeline_stage_halted? && pipeline_in_progress?

    # it can't be failed if it's not yet complete
    return false unless pipeline_completed?

    status == "FAILED" && status_type == "pipeline_state_completed_failed"
  end

  def error?
    return false unless pipeline_completed?
    status == "ERROR" && status_type == "pipeline_state_completed_error"
  end

  def halted?
    return unless pipeline_completed?
    status == "STOPPED" && status_type == "pipeline_state_completed_stopped"
  end

  def artifacts_url
    true
  end

  def started_at
    workflow_payload[:created_on]
  end

  def finished_at
    workflow_payload[:completed_on]
  end

  private

  attr_reader :workflow_payload

  def pipeline_completed?
    pipeline_status_type == "pipeline_state_completed" && pipeline_status == "COMPLETED"
  end

  def pipeline_in_progress?
    pipeline_status_type == "pipeline_state_in_progress" && pipeline_status == "IN_PROGRESS"
  end

  def pipeline_stage_halted?
    pipeline_stage&.fetch(:name, nil) == "HALTED" &&
      pipeline_stage&.fetch(:type, nil) == "pipeline_state_in_progress_halted"
  end

  def status
    workflow_payload[:state][:result][:name]
  end

  def status_type
    workflow_payload[:state][:result][:type]
  end

  def pipeline_status
    workflow_payload[:state][:name]
  end

  def pipeline_status_type
    workflow_payload[:state][:type]
  end

  def pipeline_stage
    workflow_payload.dig(:state, :stage)
  end
end
