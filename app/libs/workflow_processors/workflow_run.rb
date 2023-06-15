class WorkflowProcessors::WorkflowRun
  include Memery
  GITHUB = WorkflowProcessors::Github::WorkflowRun
  BITRISE = WorkflowProcessors::Bitrise::WorkflowRun

  class WorkflowRunUnknownStatus < StandardError; end

  def self.process(step_run)
    new(step_run).process
  end

  def initialize(step_run)
    @step_run = step_run
  end

  def process
    return re_enqueue if in_progress?
    update_status!
  end

  private

  def re_enqueue
    WorkflowProcessors::WorkflowRunJob.set(wait: wait_time).perform_later(step_run.id)
  end

  attr_reader :step_run
  delegate :train, :release, to: :step_run
  delegate :in_progress?, :successful?, :failed?, :halted?, :artifacts_url, to: :runner

  def update_status!
    if successful?
      step_run.artifacts_url = artifacts_url
      step_run.finish_ci!
      step_run.event_stamp!(reason: :ci_finished, kind: :success, data: stamp_data)
    elsif failed?
      step_run.fail_ci!
      step_run.event_stamp!(reason: :ci_workflow_failed, kind: :error, data: stamp_data)
    elsif halted?
      step_run.cancel_ci!
      step_run.event_stamp!(reason: :ci_workflow_halted, kind: :error, data: stamp_data)
    else
      raise WorkflowRunUnknownStatus
    end
  end

  memoize def runner
    return GITHUB.new(workflow_run) if github_integration?
    BITRISE.new(step_run.ci_cd_provider, workflow_run) if bitrise_integration?
  end

  delegate :github_integration?, :bitrise_integration?, to: :integration

  def integration
    step_run.ci_cd_provider.integration
  end

  memoize def workflow_run
    step_run.get_workflow_run
  end

  def wait_time
    if Rails.env.development?
      1.minute
    else
      2.minutes
    end
  end

  def stamp_data
    {
      ref: step_run.ci_ref,
      url: step_run.ci_link
    }
  end
end
