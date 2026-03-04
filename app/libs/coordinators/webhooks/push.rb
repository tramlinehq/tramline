class Coordinators::Webhooks::Push < Coordinators::Webhooks::Base
  def process
    return Response.new(:accepted) if valid_tag?
    return Response.new(:accepted, "Invalid repo/branch") unless valid_repo_and_branch?

    if working_branch_cherry_pick_push?
      Webhooks::WorkingBranchPushJob.perform_async(cherry_pick_release.id, head_commit.to_h, rest_commits.map(&:to_h))
      return Response.new(:accepted)
    end

    return Response.new(:accepted, "No release") unless release
    return Response.new(:accepted) unless release.committable?
    return Response.new(:accepted, "Skipping the commit") unless relevant_commit?

    Webhooks::PushJob.perform_async(release.id, head_commit.to_h, rest_commits.map(&:to_h))
    Response.new(:accepted)
  end

  private

  delegate :branch_name, :repository_name, :valid_tag?, :head_commit, :rest_commits, to: :runner

  memoize def runner
    return GITHUB::Push.new(payload) if vcs_provider.integration.github_integration?
    return GITLAB::Push.new(payload, train) if vcs_provider.integration.gitlab_integration?
    BITBUCKET::Push.new(payload, train) if vcs_provider.integration.bitbucket_integration?
  end

  def relevant_commit?
    release.release_branch == branch_name
  end

  def valid_repo_and_branch?
    (train.app.vcs_provider&.code_repository_name == repository_name) if branch_name
  end

  def working_branch_cherry_pick_push?
    branch_name == train.working_branch &&
      train.almost_trunk? &&
      train.cherry_pick? &&
      cherry_pick_release&.committable?
  end

  memoize def cherry_pick_release
    train.ongoing_release
  end
end
