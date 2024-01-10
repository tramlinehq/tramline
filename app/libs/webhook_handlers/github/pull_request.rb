class WebhookHandlers::Github::PullRequest
  using RefinedHash
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def head_branch_name
    payload[:pull_request][:head][:ref]
  end

  def base_branch_name
    payload[:pull_request][:base][:ref]
  end

  def closed?
    pull_request[:state] == "closed"
  end

  def opened?
    pull_request[:state] == "open"
  end

  def repository_name
    payload[:repository][:full_name]
  end

  def pull_request
    Installations::Response::Keys
      .transform([payload[:pull_request]], GithubIntegration::PR_TRANSFORMATIONS)
      .first
      .merge_if_present(source: :github)
  end
end
