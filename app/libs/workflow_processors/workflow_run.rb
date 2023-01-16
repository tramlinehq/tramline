class WorkflowProcessors::WorkflowRun
  include Memery
  GITHUB = WorkflowProcessors::Github::WorkflowRun
  BITRISE = WorkflowProcessors::Bitrise::WorkflowRun

  def self.process(step_run)
    new(step_run).process
  end

  def initialize(step_run)
    @step_run = step_run
  end

  def process
    WorkflowProcessors::WorkflowRunJob.set(wait: wait_time).perform_later(step_run.id) if in_progress?

    return update_status! unless successful?
    upload_artifact!
    update_status!
    send_notification!
  end

  private

  attr_reader :step_run
  delegate :train, :release, to: :step_run
  delegate :in_progress?, :successful?, :failed?, :halted?, :artifacts_url, to: :runner

  def update_status!
    step_run.finish_ci! and return if successful?
    step_run.fail_ci! and return if failed?
    step_run.cancel_ci! if halted?
    # FIXME: add a catchall to fail the run
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
    return GITHUB.new(workflow_run) if github?
    BITRISE.new(step_run.ci_cd_provider, workflow_run) if bitrise?
  end

  def github?
    integration.github_integration?
  end

  def bitrise?
    integration.bitrise_integration?
  end

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
