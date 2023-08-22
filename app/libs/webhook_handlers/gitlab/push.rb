class WebhookHandlers::Gitlab::Push
  attr_reader :payload, :train

  def initialize(payload, train)
    @payload = payload
    @train = train
  end

  def head_commit_attributes
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

  def rest_commit_attributes
    []
  end

  # we do not listen to gitlab tag events, they are not included in the push events as with github
  def valid_tag?
    false
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
