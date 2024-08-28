class Coordinators::Webhooks::Gitlab::Push
  attr_reader :payload, :train

  def initialize(payload, train)
    @payload = payload
    @train = train
  end

  def head_commit
    head_commit_payload
      .find { |commit| commit[:commit_hash] == head_sha }
  end

  def rest_commits
    commits_payload
      .reject { |commit| commit[:commit_hash] == head_sha }
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
    payload["commits"].presence || []
  end

  def head_sha
    payload["checkout_sha"]
  end

  def head_commit_payload
    return [train.vcs_provider.get_commit(head_sha)] if commits.blank?
    commits_payload
  end

  def commits_payload
    Installations::Response::Keys.transform(commits, GitlabIntegration::COMMITS_HOOK_TRANSFORMATIONS)
  end
end
