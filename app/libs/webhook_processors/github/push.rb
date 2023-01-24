class WebhookProcessors::Github::Push
  def self.process(train_run, commit_attributes)
    new(train_run, commit_attributes).process
  end

  def initialize(train_run, commit_attributes)
    @train_run = train_run
    @commit_attributes = commit_attributes
  end

  def process
    release.with_lock do
      return unless release.committable?

      bump_version!
      release.start!
      release.update(release_version: train.version_current)
      create_commit!
    end
  end

  private

  attr_reader :train_run, :commit_attributes
  delegate :train, to: :release
  alias_method :release, :train_run

  def bump_version!
    return if release.step_runs.none?

    train.bump_version!(:patch)
    stamp_version_changed
  end

  def create_commit!
    params = {
      train:,
      train_run: release,
      commit_hash: commit_attributes[:commit_sha],
      message: commit_attributes[:message],
      timestamp: commit_attributes[:timestamp],
      author_name: commit_attributes[:author_name],
      author_email: commit_attributes[:author_email],
      url: commit_attributes[:url]
    }

    Releases::Commit.find_or_create_by!(params)
  end

  def send_notification!
    return unless release.commits.size.eql?(1)

    train.notify!(
      "New release has commenced!",
      :release_started,
      {
        train_name: train.name,
        version_number: train.version_current,
        commit_msg: commit_attributes[:message],
        branch_name: commit_attributes[:branch_name]
      }
    )
  end

  def stamp_version_changed
    release.event_stamp_now!(
      reason: :version_changed,
      kind: :notice,
      data: {version: train.version_current}
    )
  end
end
