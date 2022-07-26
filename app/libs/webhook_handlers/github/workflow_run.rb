require "zip"

class WebhookHandlers::Github::WorkflowRun
  Response = Struct.new(:status, :body)
  attr_reader :train, :payload, :release
  delegate :transaction, to: ApplicationRecord

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
    @release = train.active_run
  end

  def process
    return Response.new(:accepted) unless successful?
    return Response.new(:unprocessable_entity) if train.blank?
    return Response.new(:unprocessable_entity) if train.inactive?
    return Response.new(:accepted) if release.blank?
    return Response.new(:accepted) if step_run.blank?

    transaction do
      add_step_run_meta_data
      finish_step_run
      upload_artifact
      notify
    end

    Response.new(:accepted)
  end

  private

  def add_step_run_meta_data
    step_run.update!(ci_ref: payload[:workflow_run][:id], ci_link: payload[:workflow_run][:html_url])
  end

  def finish_step_run
    step_run.wrap_up_run!
  end

  def upload_artifact
    return if step_run.step.external_deployment?

    Releases::Step::UploadArtifact.perform_later(step_run.id, installation_id, artifacts_url)
  end

  def notify
    release_branch = release.release_branch
    code_name = release.code_name
    build_number = train.app.build_number
    version_number = train.version_current

    text_block =
      Notifiers::Slack::BuildFinished.render_json(
        artifact_link: artifacts_url,
        code_name:,
        branch_name: release_branch,
        build_number:,
        version_number:
      )

    Automatons::Notify.dispatch!(
      train:,
      message: "Your release workflow completed!",
      text_block:
    )
  end

  def step_run
    @step_run ||= begin
      version_zip = installation.artifact_io_stream(version_artifact_url)

      build_number = Zip::File.open(version_zip).entries.first.get_input_stream.read.strip
      release.step_runs.on_track.find_by(build_number: build_number)
    end
  end

  def version_artifact_url
    installation
      .artifacts(artifacts_url)
      .find { |artifact| artifact["name"] == "version" }["archive_download_url"]
  end

  def successful?
    complete_action? || payload_status == "completed" && payload_conclusion == "success"
  end

  def payload_status
    payload[:workflow_run][:status]
  end

  def payload_conclusion
    payload[:workflow_run][:conclusion]
  end

  def artifacts_url
    payload[:workflow_run][:artifacts_url]
  end

  # TODO Workaround as it seems that github's status field is not consistent
  def complete_action?
    payload[:action] == "completed"
  end

  def artifacts_name
    installation.artifact_filename(artifacts_url)
  end

  def installation
    @installation ||= Installations::Github::Api.new(installation_id)
  end

  def installation_id
    @installation_id ||= train.ci_cd_provider.installation_id
  end
end
