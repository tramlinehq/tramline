class WorkflowProcessors::WorkflowRun
  include Memery

  def self.process(step_run)
    new(step_run).process
  end

  def initialize(step_run)
    @step_run = step_run
  end

  GITHUB = WorkflowProcessors::Github::WorkflowRun
  BITRISE = WorkflowProcessors::Bitrise::WorkflowRun

  def process
    WorkflowProcessors::WorkflowRunJob.set(wait: wait_time).perform_later(step_run.id) if in_progress?

    return update_status! unless successful?

    transaction do
      update_status!
      upload_artifact!
    end

    # This is outside the transaction since upload artifact is non-rollbackable.
    send_notification!
  end

  private

  attr_reader :step_run
  delegate :transaction, to: Releases::Step::Run
  delegate :train, :release, to: :step_run
  delegate :in_progress?, :successful?, :failed?, :halted?, :artifacts_url, to: :runner

  def update_status!
    step_run.finish_ci! and return if successful?
    step_run.fail_ci! and return if failed?
    step_run.cancel_ci! if halted?
  end

  def upload_artifact!
    Releases::Step::UploadArtifact.perform_later(step_run.id, artifacts_url)
  end

  def send_notification!
    branch_name = release.release_branch
    code_name = release.code_name
    build_number = step_run.build_number
    version_number = step_run.build_version
    message = "Your release workflow completed!"
    text_block = Notifiers::Slack::BuildFinished.render_json(artifacts_url:, code_name:, branch_name:, build_number:, version_number:)
    Triggers::Notification.dispatch!(train:, message:, text_block:)
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
