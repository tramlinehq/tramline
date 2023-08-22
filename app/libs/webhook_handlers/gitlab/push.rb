class WebhookHandlers::Gitlab::Push
  attr_reader :payload, :train

  def initialize(payload, train)
    @payload = payload
    @train = train
  end

  def head_commit
    commit_attributes(head_commit_payload)
  end

  def rest_commits
    rest_commits_payload.map { commit_attributes(_1) }
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

  private

  def commits
    payload["commits"]
  end

  def commit_attributes(commit)
    {
      commit_sha: commit_sha(commit),
      message: commit[:message],
      timestamp: timestamp(commit),
      author_name: author_name(commit),
      author_email: author_email(commit),
      url: url(commit),
      branch_name: branch_name
    }
  end

  def commit_sha(commit)
    commit[:commit_sha] || commit["id"]
  end

  def timestamp(commit)
    commit[:timestamp] || commit["authored_date"]
  end

  def author_name(commit)
    commit[:author_name] || commit["author"]["name"]
  end

  def author_email(commit)
    commit[:author_email] || commit["author"]["email"]
  end

  def url(commit)
    commit[:url] || commit["web_url"]
  end

  def head_sha
    payload["checkout_sha"]
  end

  def head_commit_payload
    return train.vcs_provider.get_commit(head_sha) if commits.blank?
    commits.find { |commit| commit["id"] == head_sha }
  end

  def rest_commits_payload
    commits&.reject { |commit| commit["id"] == head_sha }.presence || []
  end
end
