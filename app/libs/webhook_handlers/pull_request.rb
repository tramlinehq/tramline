class WebhookHandlers::PullRequest < WebhookHandlers::Base
  def process
    return Response.new(:accepted) unless valid_branch?
    return Response.new(:accepted, "No release") unless release
    return Response.new(:accepted) unless release.committable?
    return Response.new(:accepted, "PR was not closed or merged") unless closed?
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo_and_branch?

    WebhookProcessors::PullRequest.perform_later(release.id, pull_request)
    Response.new(:accepted)
  end

  private

  delegate :pull_request, :closed?, :branch_name, to: :runner

  memoize def runner
    return GITHUB::PullRequest.new(payload) if vcs_provider.integration.github_integration?
    GITLAB::PullRequest.new(payload, train) if vcs_provider.integration.gitlab_integration?
  end

  def valid_branch?
    release.branch_name == branch_name
  end

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end
end
