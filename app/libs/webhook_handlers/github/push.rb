class WebhookHandlers::Github::Push
  include Memery

  attr_reader :payload

  def initialize(payload)
    @payload = payload
  end

  def head_commit_attributes
    commit_attributes(head_commit)
  end

  def rest_commit_attributes
    commits.map { commit_attributes(_1) }
  end

  def commit_attributes(commit)
    {
      commit_sha: commit["id"],
      message: commit["message"],
      timestamp: commit["timestamp"],
      author_name: commit["author"]["name"],
      author_email: commit["author"]["email"],
      url: commit["url"],
      branch_name: branch_name
    }
  end

  memoize def head_commit
    payload["head_commit"]
  end

  memoize def commits
    payload["commits"]
      &.reject { |commit| commit["id"] == head_commit["id"] }
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
end
