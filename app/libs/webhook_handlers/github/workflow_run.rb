require 'zip'

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
      finish_step_run
      upload_artifact
      upload_artifact_build_channel
      notify
    end

    Response.new(:accepted)
  end

  private

  def finish_step_run
    step_run.wrap_up_run!
  end

  def upload_artifact
    Releases::Step::UploadArtifact.perform_now(step_run.id, installation_id, artifacts_url)
  end

  def upload_artifact_build_channel
    # FIXME: move to background job
    app = train.app
    step_run.reload
    file = step_run.build_artifact.file.blob.open do |file|
      Zip::File.open(file).glob("*.aab").first.get_input_stream
    end
    api = Installations::Google::PlayDeveloper::Api.new(app.bundle_identifier,
      file,
      StringIO.new(app.integrations.build_channel_provider.json_key),
      train.version_current)
    api.upload
    api.release
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
    @step_run ||= release.step_runs.find_by(ci_ref: payload["workflow_run"]["id"])
  end

  def step
    step_run.step
  end

  def successful?
    payload_status == "completed" && payload_conclusion == "success"
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

  def installation_id
    @installation_id ||= train.ci_cd_provider.installation_id
  end
end
