class Triggers::PatchPullRequest
  def self.call(release, commit)
    new(release, commit).call
  end

  def initialize(release, commit)
    @release = release
    @commit = commit
    @pull_request = Triggers::PullRequest.new(
      release: release,
      new_pull_request_attrs: {phase: :ongoing, release_id: release.id, state: :open, commit_id: commit.id},
      to_branch_ref: working_branch,
      from_branch_ref: patch_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: commit.pull_requests.find_by(base_ref: train.working_branch),
      patch_pr: true,
      patch_commit: commit
    )
  end

  def call
    return GitHub::Result.new if bot_commit?

    result = @pull_request.create_and_merge!

    return result unless result.ok?
    return result unless train.backmerge_to_upcoming_release

    upcoming_release = train.upcoming_release
    return result unless upcoming_release
    return result if upcoming_release == release

    upcoming_release_pr = Triggers::PullRequest.new(
      release: release,
      new_pull_request_attrs: {phase: :ongoing, release_id: release.id, state: :open, commit_id: commit.id},
      to_branch_ref: upcoming_release.branch_name,
      from_branch_ref: patch_branch(upcoming_release.branch_name),
      title: pr_title,
      description: pr_description,
      existing_pr: commit.pull_requests.find_by(base_ref: upcoming_release.branch_name),
      patch_pr: true,
      patch_commit: commit
    )
    upcoming_release_pr.create_and_merge!
  end

  private

  delegate :logger, to: Rails
  delegate :train, to: :release
  delegate :working_branch, :continuous_backmerge_branch_prefix, to: :train
  attr_reader :release, :commit

  def pr_title
    "[PATCH] [#{release.release_version}] #{commit.message.split("\n").first}".gsub(/\s*\(#\d+\)/, "").squish
  end

  def pr_description
    <<~TEXT
      - Cherry-pick #{commit.commit_hash} commit
      - Authored by: @#{commit.author_login || commit.author_name}

      #{commit.message}
    TEXT
  end

  def bot_commit?
    commit.author_login == "tramline-github-dev[bot]"
  end

  def patch_branch(target_branch = working_branch)
    [continuous_backmerge_branch_prefix, "patch", target_branch, commit.short_sha].compact_blank.join("-")
  end
end
