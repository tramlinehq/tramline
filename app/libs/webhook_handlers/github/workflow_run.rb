class WebhookHandlers::Github::WorkflowRun
  Response = Struct.new(:status, :body)
  attr_reader :train, :payload

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def process
    return Response.new(:accepted) unless successful?
    return Response.new(:unprocessable_entity) if train.blank?
    return Response.new(:unprocessable_entity) if train.inactive?
    return Response.new(:accepted) if train.current_run.blank?
    return Response.new(:accepted) if train.current_run.last_running_step.blank?

    release_branch = train.current_run.release_branch
    code_name = train.current_run.code_name
    build_number = train.app.build_number
    version_number = train.version_current

    transaction do
      text_block =
        Notifiers::Slack::BuildFinished.render_json(
          artifact_link: artifacts_url,
          code_name:,
          branch_name: release_branch,
          build_number:,
          version_number:
        )

      current_run.last_running_step.wrap_up_run!

      Automatons::Notify.dispatch!(
        train:,
        message: 'Your release workflow completed!',
        text_block:
      )
    end

    Response.new(:accepted)
  end

  private

  def successful?
    payload_status == 'completed' && payload_conclusion == 'success'
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
end
