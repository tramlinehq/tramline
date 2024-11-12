class Coordinators::Webhooks::CommitMonitor < Coordinators::Webhooks::Base
  def process
    return Response.new(:accepted, "Not a valid branch push") unless valid_branch_push?
    return Response.new(:accepted, "Branch not monitored") unless monitored_branch?
    
    Webhooks::CommitMonitorJob.perform_later(
      release.id,
      head_commit,
      rest_commits
    )
    Response.new(:accepted)
  end

  private

  delegate :repository_name, :head_commit, :rest_commits, to: :runner

  memoize def runner
    if vcs_provider.integration.github_integration?
      WebhookHandlers::Github::Commit.new(payload)
    elsif vcs_provider.integration.gitlab_integration?
      WebhookHandlers::Gitlab::Push.new(payload, train)
    elsif vcs_provider.integration.bitbucket_integration?
      WebhookHandlers::Bitbucket::Push.new(payload, train)
    end
  end

  def branch_name
    runner.branch_name
  end

  def valid_branch?
    runner.valid_branch?
  end

  def valid_tag?
    runner.valid_tag?
  end

  def valid_branch_push?
    result = valid_branch? && !valid_tag?
    result
  end

  def monitored_branch?
    result = CommitMonitorConfig.monitoring?(branch_name)
    result
  end
end 