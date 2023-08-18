class WebhookProcessors::Push
  def self.process(release, commit_attributes)
    new(release, commit_attributes).process
  end

  def initialize(release, commit_attributes)
    @release = release
    @commit_attributes = commit_attributes
  end

  def process
    release.with_lock do
      return unless release.committable?

      release.close_pre_release_prs
      bump_version!
      release.start!
      create_commit!
    end
  end

  private

  attr_reader :release, :commit_attributes
  delegate :train, to: :release

  def bump_version!
    return unless release.version_bump_required?
    return if release.step_runs.none?

    train.bump_fix!
    stamp_version_changed
  end

  def create_commit!
    params = {
      release: release,
      commit_hash: commit_attributes[:commit_sha],
      message: commit_attributes[:message],
      timestamp: commit_attributes[:timestamp],
      author_name: commit_attributes[:author_name],
      author_email: commit_attributes[:author_email],
      url: commit_attributes[:url]
    }

    commit = Commit.find_or_create_by!(params)
    commit.trigger_step_runs if commit.applicable?
  end

  def stamp_version_changed
    release.event_stamp_now!(
      reason: :version_changed,
      kind: :notice,
      data: {version: train.version_current}
    )
  end
end
