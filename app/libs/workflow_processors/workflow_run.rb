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
    send_notification! if successful?
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
    elsif failed?
      step_run.fail_ci!
    elsif halted?
      step_run.cancel_ci!
    else
      raise WorkflowRunUnknownStatus
    end
  end

  def upload_artifact!
    Releases::UploadArtifact.perform_later(step_run.id, artifacts_url)
  end

  def send_notification!
    train.notify!(
      "New build was created!",
      :build_finished,
      {
        artifacts_url:,
        code_name: release.code_name,
        branch_name: release.release_branch,
        build_number: step_run.build_number,
        version_number: step_run.build_version
      }
    )
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
end
