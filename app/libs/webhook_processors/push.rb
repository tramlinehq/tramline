class WebhookProcessors::Push
  include Loggable

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

      if release.created?
        release.start!
        release.release_platform_runs.each(&:start!)
      end

      create_other_commits!
      create_head_commit!
    end

    # TODO: [V2] move this to trigger release
    if release.all_commits.size.eql?(1)
      release.notify!("New release has commenced!", :release_started, release.notification_params)
    end
  end

  private

  delegate :train, to: :release
  attr_reader :release, :head_commit, :rest_commits

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
      .merge(parents: commit_log.find { _1[:commit_hash] == attributes[:commit_hash] }&.dig(:parents))
  end

  # TODO: fetch parents for Gitlab commits also
  def commit_log
    return @commit_log ||= [train.vcs_provider.get_commit(head_commit[:commit_hash])] if rest_commits.empty?

    @commit_log ||= train.vcs_provider.commit_log(rest_commits.first[:commit_hash], head_commit[:commit_hash])
    @commit_log << train.vcs_provider.get_commit(rest_commits.first[:commit_hash])
  rescue => e
    elog(e)
    @commit_log = []
  end
end
