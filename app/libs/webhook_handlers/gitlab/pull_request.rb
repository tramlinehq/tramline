class WebhookHandlers::Gitlab::PullRequest
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def branch_name
    payload["pull_request"]["head"]["ref"]
  end

  def closed?
    pull_request[:state] == "closed" || pull_request[:state] == "merged"
  end

  def pull_request
    Installations::Response::Keys
      .transform([payload["pull_request"]], GitlabIntegration::PR_TRANSFORMATIONS)
      .merge(source: :gitlab)
  end
end
