class Triggers::ReleaseBackmerge
  include Loggable

  PR_TITLE = "[%s] Continuous merge back from release"
  PR_DESCRIPTION = <<~TEXT
    Release %s (%s) has new changes on this release branch.
    Merge these changes back into `%s` to keep it in sync.
  TEXT

  def self.call(commit)
    new(commit).call
  end

  def initialize(commit)
    @commit = commit
    @release = commit.release
  end

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
          title: PR_TITLE % release_version,
          description: PR_DESCRIPTION % [release_version, train.name, working_branch],
          existing_pr: release.pull_requests.ongoing.open.first
        )
      end
    end

    if res && !res.ok?
      elog(res.error)
      commit.update!(backmerge_failure: true)
      release.event_stamp!(reason: :backmerge_failure, kind: :error, data: {commit_url: commit.url, commit_sha: commit.short_sha})
      commit.notify!("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end

  private

  attr_reader :release, :commit
  delegate :train, :release_branch, :release_version, to: :release
  delegate :working_branch, to: :train
end
