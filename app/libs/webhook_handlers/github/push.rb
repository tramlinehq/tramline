class WebhookHandlers::Github::Push
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def head_commit
    head_commit_payload.merge(branch_name:)
  end

  def rest_commits
    rest_commits_payload
      &.reject { |commit| commit[:commit_hash] == head_commit[:commit_hash] }.presence || []
  end

  def valid_branch?
    payload["ref"]&.include?("refs/heads/")
  end

  # github adds tag events as part of the push events
  def valid_tag?
    payload["ref"]&.include?("refs/tags/")
  end

  def branch_name
    payload["ref"].delete_prefix("refs/heads/") if valid_branch?
  end

  def repository_name
    payload["repository"]["full_name"]
  end

  private

  def head_commit_payload
    Installations::Response::Keys
      .transform([payload["head_commit"]], GithubIntegration::COMMITS_HOOK_TRANSFORMATIONS)
      .first
  end

  def rest_commits_payload
    Installations::Response::Keys.transform(payload["commits"], GithubIntegration::COMMITS_HOOK_TRANSFORMATIONS)
  end
end
