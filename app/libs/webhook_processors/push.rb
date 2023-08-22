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
      release.start!
      create_commit!
    end
  end

  private

  attr_reader :release, :commit_attributes
  delegate :train, to: :release

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

    Commit.find_or_create_by!(params).apply!
  end
end
