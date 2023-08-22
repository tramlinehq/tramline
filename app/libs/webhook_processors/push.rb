class WebhookProcessors::Push
  def self.process(release, commit_attributes)
    new(release, commit_attributes).process
  end

  def initialize(release, head_commit_attributes, rest_commit_attributes = [])
    @release = release
    @head_commit_attributes = head_commit_attributes
    @rest_commit_attributes = rest_commit_attributes
  end

  def process
    release.with_lock do
      return unless release.committable?

      release.close_pre_release_prs
      release.start!
      create_head_commit!
      create_other_commits!
    end
  end

  private

  attr_reader :release, :head_commit_attributes, :rest_commit_attributes
  delegate :train, to: :release

  def create_head_commit!
    Commit.find_or_create_by!(commit_params(head_commit_attributes)).trigger_step_runs
  end

  def create_other_commits!
    rest_commit_attributes.each do |commit_attributes|
      Commit.find_or_create_by!(commit_params(commit_attributes))
    end
  end

  def commit_params(attributes)
    {
      release: release,
      commit_hash: attributes[:commit_sha],
      message: attributes[:message],
      timestamp: attributes[:timestamp],
      author_name: attributes[:author_name],
      author_email: attributes[:author_email],
      url: attributes[:url]
    }
  end
end
