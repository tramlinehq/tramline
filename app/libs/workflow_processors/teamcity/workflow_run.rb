class WorkflowProcessors::Teamcity::WorkflowRun
  # TeamCity build states:
  # - queued: Build is waiting in the queue
  # - running: Build is currently executing
  # - finished: Build has completed
  #
  # TeamCity build statuses (when finished):
  # - SUCCESS: Build completed successfully
  # - FAILURE: Build failed
  # - ERROR: Build errored (infrastructure issue)
  # - UNKNOWN: Build status unknown

  def initialize(integration, workflow_run, build_artifact_name_pattern)
    @integration = integration
    @workflow_run = workflow_run
    @build_artifact_name_pattern = build_artifact_name_pattern
  end

  def in_progress?
    state == "queued" || state == "running"
  end

  def successful?
    finished? && status == "success"
  end

  def failed?
    finished? && status == "failure"
  end

  def halted?
    finished? && workflow_run[:canceledInfo].present?
  end

  def error?
    finished? && status == "error"
  end

  def artifacts_url
    @integration.artifact_url(workflow_run[:id], @build_artifact_name_pattern)
  end

  def started_at
    parse_teamcity_date(workflow_run[:startDate])
  end

  def finished_at
    parse_teamcity_date(workflow_run[:finishDate])
  end

  private

  attr_reader :workflow_run

  def state
    workflow_run[:state]&.downcase
  end

  def status
    workflow_run[:status]&.downcase
  end

  def finished?
    state == "finished"
  end

  # TeamCity dates are in format: 20240115T143052+0000
  def parse_teamcity_date(date_string)
    return nil unless date_string
    Time.strptime(date_string, "%Y%m%dT%H%M%S%z")
  rescue ArgumentError
    nil
  end
end
