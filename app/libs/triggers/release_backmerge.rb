class Triggers::ReleaseBackmerge
  include Loggable

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
      Triggers::PatchPullRequest.create!(release, commit)
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
  delegate :train, to: :release
end
