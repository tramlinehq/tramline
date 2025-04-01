class WorkflowProcessors::Bitrise::PipelineRun
  def initialize(pipeline_run)
    @pipeline_run = pipeline_run
  end

  def in_progress?
    %w[initializing in-progress in_progress on-hold on_hold running].include?(status)
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

  def error? = false

  def artifacts_url = nil

  def started_at
    pipeline_run[:triggered_at]
  end

  def finished_at
    pipeline_run[:finished_at]
  end

  private

  attr_reader :pipeline_run

  def status
    pipeline_run[:status]
  end
end
