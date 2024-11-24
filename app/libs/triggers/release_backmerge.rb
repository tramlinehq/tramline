class Triggers::ReleaseBackmerge
  include Loggable

  def self.call(commit)
    new(commit).call
  end

  def initialize(commit)
    @commit = commit
    @release = commit.release
  end

  # after a commit is created, backmerge is initiated
  # check is train has continuous backmerge enabled
  # if yes, check if the vcs provider supports cherry-picking
  # if yes, cherry-pick the commit
  # if no, create a new PR for the release branch to the working branch
  #
  def call
    return unless train.almost_trunk?
    return unless train.continuous_backmerge?

    res = release.with_lock do
      return GitHub::Result.new {} unless release.committable?
      if train.vcs_provider.supports_cherry_pick?
        Triggers::PatchPullRequest.create!(release, commit)
      else
        Triggers::PullRequest.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.ongoing.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: release_branch,
          title: pr_title,
          description: pr_description,
          existing_pr: release.pull_requests.ongoing.open.first
        )
      end
    end

    if res && !res.ok?
      elog(res.error)
      commit.update!(backmerge_failure: true)
      release.event_stamp!(reason: :backmerge_failure, kind: :error, data: { commit_url: commit.url, commit_sha: commit.short_sha })
      commit.notify!("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end

  private

  attr_reader :release, :commit
  delegate :train, :release_branch, to: :release
  delegate :working_branch, to: :train

  def pr_title
    "[#{release.release_version}] Continuous back merge from release"
  end

  def pr_description
    <<~TEXT
      The release train #{train.name} with version #{release.release_version} has new changes on the release branch.
      The #{release_branch} branch has to be merged into #{working_branch} branch to keep the working branch in sync.
    TEXT
  end
end
