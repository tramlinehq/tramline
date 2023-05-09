class WebhookHandlers::Github::Push
  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def commit_attributes
    {
      commit_sha: head_commit["id"],
      message: head_commit["message"],
      timestamp: head_commit["timestamp"],
      author_name: head_commit["author"]["name"],
      author_email: head_commit["author"]["email"],
      url: head_commit["url"],
      branch_name: branch_name
    }
  end

  def head_commit
    @head_commit ||= payload["head_commit"]
  end

  def valid_branch?
    payload["ref"]&.include?("refs/heads/")
  end

  def valid_tag?
    payload["ref"]&.include?("refs/tags/")
  end

  def branch_name
    payload["ref"].delete_prefix("refs/heads/") if valid_branch?
  end

  def repository_name
    payload["repository"]["full_name"]
  end
end
