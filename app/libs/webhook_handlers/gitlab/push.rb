class WebhookHandlers::Gitlab::Push
  include SiteHttp
  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def process
    return Response.new(:unprocessable_entity, "No release") unless release
    return Response.new(:accepted) unless release.committable?
    return Response.new(:unprocessable_entity, "Skipping the commit") unless relevant_commit?
    return Response.new(:unprocessable_entity, "Invalid repo/branch") unless valid_repo_and_branch?

    if train.commit_listeners.exists?(branch_name:)
      WebhookProcessors::Github::PushJob.perform_later(release.id, commit_attributes)
    end

    Response.new(:accepted)
  end

  private

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

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end

  # TODO: See if we can rely on the commit listener instead
  def relevant_commit?
    release.release_branch == branch_name
  end

  def release
    @release ||= train.active_run
  end
end
