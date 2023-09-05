class WebhookHandlers::Github::PullRequest
  using RefinedHash
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def branch_name
    payload[:head][:ref]
  end

  def closed?
    pull_request[:state] == "closed"
  end

  def repository_name
    payload[:head][:repo][:full_name]
  end

  def pull_request
    Installations::Response::Keys
      .transform([payload], GithubIntegration::PR_TRANSFORMATIONS)
      .first
      .merge_if_present(source: :github)
  end
end
