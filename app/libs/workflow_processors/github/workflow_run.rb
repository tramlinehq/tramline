class WorkflowProcessors::Github::WorkflowRun
  include Memery

  def self.process(step_run)
    new(step_run).process
  end

  def initialize(step_run)
    @step_run = step_run
  end

  def process
    WorkflowProcessors::WorkflowRun.set(wait: wait_time).perform_later(step_run.id) if in_progress?

    return update_status! unless successful?

    transaction do
      update_status!
      upload_artifact!
      send_notification!
    end
  end

  private

  attr_reader :step_run, :workflow_run_attrs
  delegate :transaction, to: Releases::Step::Run
  delegate :train, :release, to: :step_run

  def update_status!
    step_run.finish_ci! and return if successful?
    step_run.fail_ci! and return if failed?
    step_run.cancel_ci! if halted?
  end

  def upload_artifact!
    Releases::Step::UploadArtifact.perform_later(step_run.id, installation_id, artifacts_url)
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

  def in_progress?
    status == "in_progress" || status == "queued"
  end

  def successful?
    status == "completed" && conclusion == "success"
  end

  def failed?
    conclusion == "failure"
  end

  def halted?
    status == "completed" && conclusion == "cancelled"
  end

  def status
    workflow_run[:status]
  end

  def conclusion
    workflow_run[:conclusion]
  end

  def artifacts_url
    workflow_run[:artifacts_url]
  end

  def installation_id
    train.ci_cd_provider.installation_id
  end

  def wait_time
    if Rails.env.development?
      2.minutes
    else
      5.minutes
    end
  end

  memoize def workflow_run
    step_run.get_workflow_run
  end
end
