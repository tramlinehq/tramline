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
    return Response.new(:accepted) unless complete_action?
    return Response.new(:unprocessable_entity) if train.blank?
    return Response.new(:unprocessable_entity) if train.inactive?
    return Response.new(:accepted) if release.blank?

    WebhookProcessors::Github::WorkflowRun.perform_later(release.id, workflow_attributes)
    Response.new(:accepted)
  end

  private

  def workflow_attributes
    {
      conclusion: conclusion,
      artifacts_url: artifacts_url,
      ci_ref: payload[:workflow_run][:id],
      ci_link: payload[:workflow_run][:html_url]
    }
  end

  def conclusion
    return :success if successful?
    return :failed if failed?
    :halted if halted?
  end

  # TODO: These checks are a workaround because Github's action, status and conclusion fields can be pretty unreliable
  def successful?
    (complete_action? && payload_status == "in_progress") ||
      (payload_status == "completed" && payload_conclusion == "success")
  end

  def failed?
    complete_action? && payload_conclusion == "failure"
  end

  def halted?
    complete_action? && payload_status == "completed" && payload_conclusion == "cancelled"
  end

  def payload_status
    payload[:workflow_run][:status]
  end

  def payload_conclusion
    payload[:workflow_run][:conclusion]
  end

  def payload_action
    payload[:github][:action]
  end

  def artifacts_url
    payload[:workflow_run][:artifacts_url]
  end

  def complete_action?
    payload_action == "completed"
  end
end
