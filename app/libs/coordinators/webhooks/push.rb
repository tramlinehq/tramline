class Coordinators::Webhooks::Push < Coordinators::Webhooks::Base
  def process
    return Response.new(:accepted) if valid_tag?
    return Response.new(:accepted, "No release") unless release
    return Response.new(:accepted) unless release.committable?
    return Response.new(:accepted, "Skipping the commit") unless relevant_commit?
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo_and_branch?

    Webhooks::PushJob.perform_later(release.id, head_commit, rest_commits)
    Response.new(:accepted)
  end

  private

  delegate :branch_name, :repository_name, :valid_tag?, :head_commit, :rest_commits, to: :runner

  memoize def runner
    return GITHUB::Push.new(payload) if vcs_provider.integration.github_integration?
    GITLAB::Push.new(payload, train) if vcs_provider.integration.gitlab_integration?
  end

  def relevant_commit?
    release.release_branch == branch_name
  end

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end
end
