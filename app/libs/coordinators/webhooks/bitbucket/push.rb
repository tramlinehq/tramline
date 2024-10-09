class Coordinators::Webhooks::Bitbucket::Push
  attr_reader :payload, :train

  def initialize(payload, train)
    @payload = payload
    @train = train
  end

  def head_commit
    if head_commit_payload
      Installations::Response::Keys.transform([head_commit_payload], BitbucketIntegration::COMMITS_TRANSFORMATIONS)
        .first
        .then { |commit| Installations::Bitbucket::Api.parse_author_info(commit) }
    else
      train.vcs_provider.head(repository_name, branch_name)
    end
  end

  def rest_commits
    commits_payload.reject { |commit| commit[:commit_hash] == head_sha }
  end

  def valid_tag?
    payload_change.dig("type") == "tag"
  end

  def valid_branch?
    payload_change.dig("type") == "branch" && branch_name.present?
  end

  def branch_name
    payload_change.dig("name")
  end

  def repository_name
    payload.dig("repository", "full_name")
  end

  private

  def payload_change
    payload.dig("push", "changes", 0, "new")
  end

  def new_branch?
    payload_change.dig("type") == "branch" && payload.dig("push", "changes", 0, "created") == true
  end

  def commits
    return [] if new_branch?
    payload.dig("push", "changes", 0, "commits").presence || []
  end

  def head_sha
    payload_change["target"]["hash"]
  end

  def head_commit_payload
    if payload_change["target"]["type"] == "commit"
      payload_change["target"]
    end
  end

  def commits_payload
    Installations::Response::Keys.transform(commits, BitbucketIntegration::COMMITS_TRANSFORMATIONS)
      .map { |commit| Installations::Bitbucket::Api.parse_author_info(commit) }
  end
end
