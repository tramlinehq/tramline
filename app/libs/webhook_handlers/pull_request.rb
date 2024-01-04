class WebhookHandlers::PullRequest < WebhookHandlers::Base
  def process
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo?
    return Response.new(:accepted, "PR was not closed or merged") unless closed?
    return Response.new(:accepted, "No open active PRs") unless open_active_prs?

    WebhookProcessors::PullRequestJob.perform_later(train.id, pull_request)
    Response.new(:accepted)
  end

  private

  delegate :pull_request, :closed?, :branch_name, :repository_name, to: :runner

  memoize def runner
    return GITHUB::PullRequest.new(payload) if vcs_provider.integration.github_integration?
    GITLAB::PullRequest.new(payload) if vcs_provider.integration.gitlab_integration?
  end

  memoize def open_active_prs?
    train.open_active_prs_for?(branch_name)
  end

  def valid_repo?
    (train.app.config&.code_repository_name == repository_name)
  end
end
