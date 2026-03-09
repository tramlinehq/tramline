class Webhooks::Push < Webhooks::Base
  def process
    return if valid_tag?
    return unless release
    return unless release.committable?
    return unless relevant_commit?
    return unless valid_repo_and_branch?
    return unless valid_head_commit?

    Webhooks::PushJob.perform_async(release.id, head_commit.to_h, rest_commits.map(&:to_h))
  end

  private

  delegate :branch_name, :repository_name, :valid_tag?, :valid_head_commit?, :head_commit, :rest_commits, to: :runner

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
end
