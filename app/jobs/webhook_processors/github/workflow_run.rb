require "zip"

class WebhookProcessors::Github::WorkflowRun < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  def perform(train_run_id, workflow_attributes)
    @release = Releases::Train::Run.find(train_run_id)
    @workflow_attributes = workflow_attributes

    return update_status! unless workflow_successful?

    transaction do
      add_metadata!
      update_status!
      upload_artifact!
    end

    send_notification!
  end

  private

  attr_reader :release, :workflow_attributes

  def add_metadata!
    step_run.update!(ci_ref:, ci_link:)
  end

  def update_status!
    step_run.about_to_deploy! and return if workflow_successful?
    step_run.ci_failed! and return if workflow_failed?
    step_run.ci_cancelled! if workflow_halted?
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

  def train
    @train ||= release.train
  end

  def step_run
    @step_run ||= release.step_runs.ci_workflow_started.find_by(build_number: artifact_build_number)
  end

  def artifact_build_number
    Zip::File.open(artifact_version_zip).entries.first.get_input_stream.read.strip
  end

  def artifact_version_zip
    installation.artifact_io_stream(version_artifact_url)
  end

  def version_artifact_url
    installation.artifacts(artifacts_url).find { |artifact| artifact["name"] == "version" }["archive_download_url"]
  end

  def installation
    @installation ||= Installations::Github::Api.new(installation_id)
  end

  def installation_id
    @installation_id ||= train.ci_cd_provider.installation_id
  end

  def workflow_successful?
    workflow_attributes[:conclusion] == :success
  end

  def workflow_failed?
    workflow_attributes[:conclusion] == :failed
  end

  def workflow_halted?
    workflow_attributes[:conclusion] == :halted
  end

  def ci_ref
    workflow_attributes[:ci_ref]
  end

  def ci_link
    workflow_attributes[:ci_link]
  end

  def artifacts_url
    workflow_attributes[:artifacts_url]
  end
end
