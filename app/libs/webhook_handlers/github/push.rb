class WebhookHandlers::Github::Push
  Response = Struct.new(:status, :body)
  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def process
    return Response.new(:accepted) if valid_tag?
    return Response.new(:unprocessable_entity, "No release") unless release

    release.with_lock do
      return Response.new(:accepted) unless release.committable?
      return Response.new(:unprocessable_entity, "Skipping the commit") unless relevant_commit?
      return Response.new(:unprocessable_entity, "Invalid repo/branch") unless valid_repo_and_branch?

      if train.commit_listeners.exists?(branch_name:)
        WebhookProcessors::Github::Push.perform_later(release.id, commit_attributes)
      end

      Response.new(:accepted)
    end
  end

  private

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
