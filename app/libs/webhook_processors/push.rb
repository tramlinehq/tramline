class WebhookProcessors::Push
  def self.process(release, head_commit, rest_commits)
    new(release, head_commit, rest_commits).process
  end

  def initialize(release, head_commit, rest_commits = [])
    @release = release
    @head_commit = head_commit
    @rest_commits = rest_commits
  end

  def process
    release.with_lock do
      return unless release.committable?
      release.close_pre_release_prs
      release.start!
      create_other_commits!
      create_head_commit!
    end
  end

  private

  attr_reader :release, :head_commit, :rest_commits
  delegate :train, to: :release

  def create_head_commit!
    Commit.find_or_create_by!(commit_params(head_commit)).trigger!
  end

  def create_other_commits!
    rest_commits.each { Commit.find_or_create_by!(commit_params(_1)).add_to_build_queue!(is_head_commit: false) }
  end

  def commit_params(attributes)
    attributes
      .slice(:commit_hash, :message, :timestamp, :author_name, :author_email, :author_login, :url)
      .merge(release:)
  end
end
