class WebhookHandlers::Gitlab::Push
  attr_reader :train

  def initialize(payload)
    @payload = payload
  end

  def commit_attributes
    sha = payload["checkout_sha"]
    commit = train.vcs_provider.get_commit(sha)
    {
      commit_sha: commit[:commit_sha],
      message: commit[:message],
      timestamp: commit[:timestamp],
      author_name: commit[:author_name],
      author_email: commit[:author_email],
      url: commit[:url],
      branch_name: branch_name
    }
  end

  def valid_branch?
    payload["ref"]&.include?("refs/heads/")
  end

  def branch_name
    payload["ref"].delete_prefix("refs/heads/") if valid_branch?
  end

  def repository_name
    payload["project"]["path_with_namespace"]
  end
end
