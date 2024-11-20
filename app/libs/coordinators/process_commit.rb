class Coordinators::ProcessCommit
  include Loggable

  def self.call(release, head_commit)
    new(release, head_commit).call
  end

  def initialize(release, head_commit)
    @release = release
    @head_commit = head_commit
  end

  def call
    release.with_lock do
      return unless release.committable?
      if release.created?
        release.start!
        release.release_platform_runs.each(&:start!)
      end

      create_commit!
    end
  end

  private

  def create_commit!
    commit = Commit.find_or_create_by!(commit_params(head_commit))
    queue_commit!(commit)
  end

  def queue_commit!(commit)
    return unless release.queue_commit?
    release.active_build_queue.add_commit_build_queue!(commit)
  end

  def commit_params(attributes)
    attributes
      .slice(:commit_hash, :message, :timestamp, :author_name, :author_email, :author_login, :url)
      .merge(release:)
      .merge(parents: commit_log.find { _1[:commit_hash] == attributes[:commit_hash] }&.dig(:parents))
  end

  # TODO: fetch parents for Gitlab commits also
  def commit_log
    return @commit_log ||= [fetch_commit_parents(head_commit)] if rest_commits.empty?

    @commit_log ||= train.vcs_provider.commit_log(rest_commits.first[:commit_hash], head_commit[:commit_hash])
    @commit_log << fetch_commit_parents(rest_commits.first)
  rescue => e
    elog(e)
    @commit_log = []
  end

  def fetch_commit_parents(commit)
    return if commit.blank?
    return commit if commit[:parents].present?

    train.vcs_provider.get_commit(commit[:commit_hash])
  end

  delegate :train, to: :release
  attr_reader :release, :head_commit, :rest_commits
end
