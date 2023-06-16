class WebhookHandlers::Push
  include SiteHttp
  include Memery
  GITHUB = WebhookHandlers::Github::Push
  GITLAB = WebhookHandlers::Gitlab::Push

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
    return Response.new(:accepted, "No release") unless release
    return Response.new(:accepted) unless release.committable?
    return Response.new(:accepted, "Skipping the commit") unless relevant_commit?
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo_and_branch?

    WebhookProcessors::PushJob.perform_later(release.id, commit_attributes)


    Response.new(:accepted)
  end

  private

  delegate :vcs_provider, to: :train
  delegate :head_commit, :branch_name, :repository_name, :valid_branch?, :valid_tag?, :commit_attributes, to: :runner

  memoize def runner
    return GITHUB.new(payload) if vcs_provider.integration.github_integration?
    GITLAB.new(payload, train) if vcs_provider.integration.gitlab_integration?
  end

  def relevant_commit?
    release.release_branch == branch_name
  end

  def release
    @release ||= train.active_run
  end

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end
end
