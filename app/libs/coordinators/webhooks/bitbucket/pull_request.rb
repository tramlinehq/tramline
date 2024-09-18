class Coordinators::Webhooks::Bitbucket::PullRequest
  using RefinedHash
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def head_branch_name
    pull_request[:head_ref]
  end

  def base_branch_name
    pull_request[:base_ref]
  end

  def closed?
    pull_request[:state] == "MERGED" || pull_request[:state] == "DECLINED"
  end

  def opened?
    pull_request[:state] == "OPEN"
  end

  def repository_name
    payload.dig("repository", "full_name")
  end

  def pull_request
    Installations::Response::Keys
      .transform([payload["pullrequest"]], BitbucketIntegration::PR_TRANSFORMATIONS)
      .first
      .merge_if_present(source: :bitbucket)
  end
end
