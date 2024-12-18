class Triggers::ReleaseBackmerge
  include Loggable

  def self.call(commit, is_head_commit: false)
    new(commit, is_head_commit:).call
  end

  def initialize(commit, is_head_commit: false)
    @commit = commit
    @release = commit.release
    @is_head_commit = is_head_commit
  end

  def call
    result = release.with_lock do
      return GitHub::Result.new {} if skip_backmerge?
      Triggers::PatchPullRequest.create!(release, commit)
    end

    if result && !result.ok?
      elog(result.error)
      commit.update!(backmerge_failure: true)
      release.event_stamp!(reason: :backmerge_failure, kind: :error, data: {commit_url: commit.url, commit_sha: commit.short_sha})
      commit.notify!("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end

  private

  def skip_backmerge?
    !train.almost_trunk? ||
      !train.continuous_backmerge? ||
      (!release.vcs_provider.cherry_picks_allowed? && !is_head_commit) ||
      !release.committable? ||
      !release.release_changes?
  end

  attr_reader :release, :commit, :is_head_commit
  delegate :train, to: :release
end
