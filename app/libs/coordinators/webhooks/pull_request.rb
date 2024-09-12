class Coordinators::Webhooks::PullRequest < Coordinators::Webhooks::Base
  def process
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo?

    if opened? && train.active_release_for?(base_branch_name)
      Webhooks::OpenPullRequestJob.perform_later(train.id, pull_request)
    end

    if closed? && open_active_prs?
      Webhooks::ClosePullRequestJob.perform_later(train.id, pull_request)
    end

    Response.new(:accepted)
  end

  private

  delegate :pull_request, :closed?, :opened?, :head_branch_name, :base_branch_name, :repository_name, to: :runner

  memoize def runner
    return GITHUB::PullRequest.new(payload) if vcs_provider.integration.github_integration?
    return GITLAB::PullRequest.new(payload) if vcs_provider.integration.gitlab_integration?
    BITBUCKET::PullRequest.new(payload) if vcs_provider.integration.bitbucket_integration?
  end

  memoize def open_active_prs?
    train.open_active_prs_for?(head_branch_name)
  end

  def valid_repo?
    (train.app.config&.code_repository_name == repository_name)
  end
end
