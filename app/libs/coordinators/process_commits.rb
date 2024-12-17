class Coordinators::ProcessCommits
  include Loggable

  def self.call(release, head_commit, rest_commits)
    new(release, head_commit, rest_commits).call
  end

  def initialize(release, head_commit, rest_commits = [])
    @release = release
    @head_commit = head_commit
    @rest_commits = rest_commits
  end

  def call
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

  def create_head_commit!
    commit = Commit.find_or_create_by!(commit_params(fudge_timestamp(head_commit)))
    if release.queue_commit?
      queue_commit!(commit)
    else
      Coordinators::ApplyCommit.call(release, commit)
    end
  end

  def create_other_commits!
    rest_commits.each do |rest_commit|
      commit = Commit.find_or_create_by!(commit_params(rest_commit))
      queue_commit!(commit, can_apply: false)
    end
  end

  def queue_commit!(commit, can_apply: true)
    return unless release.queue_commit?
    release.active_build_queue.add_commit_v2!(commit, can_apply:)
  end

  def commit_params(attributes)
    attributes
      .slice(:commit_hash, :message, :timestamp, :author_name, :author_email, :author_login, :url)
      .merge(release:)
      .merge(parents: commit_log.find { _1[:commit_hash] == attributes[:commit_hash] }&.dig(:parents))
  end

  # In some VCS providers, there is no millisecond precision in the timestamp
  # So we fudge it to be 1 millisecond after the original timestamp
  # This is to ensure that the head commit is always the one on the top
  def fudge_timestamp(commit)
    original_time = commit[:timestamp]
    new_time = original_time + 0.001
    commit[:timestamp] = new_time
    commit
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
