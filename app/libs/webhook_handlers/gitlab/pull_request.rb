class WebhookHandlers::Gitlab::PullRequest
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def head_branch_name
    payload["object_attributes"]["source_branch"]
  end

  def base_branch_name
    payload["object_attributes"]["target_branch"]
  end

  def closed?
    pull_request[:state] == "closed" || pull_request[:state] == "merged"
  end

  def opened?
    pull_request[:state] == "opened"
  end

  def repository_name
    payload["project"]["path_with_namespace"]
  end

  def pull_request
    Installations::Response::Keys
      .transform([payload["object_attributes"]], GitlabIntegration::WEBHOOK_PR_TRANSFORMATIONS)
      .first
      .merge(source: :gitlab)
  end
end
