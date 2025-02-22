class Triggers::PatchPullRequest
  def self.call(release, commit)
    new(release, commit).call
  end

  def initialize(release, commit)
    @release = release
    @commit = commit
    @pull_request = Triggers::PullRequest.new(
      release: release,
      new_pull_request: (commit.pull_requests.build(release:, phase: :ongoing) if commit.pull_requests.find_by(base_ref: working_branch).blank?),
      to_branch_ref: working_branch,
      from_branch_ref: patch_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: commit.pull_requests.find_by(base_ref: working_branch),
      patch_pr: true,
      patch_commit: commit
    )
  end

  def call
    @pull_request.create_and_merge!

    if train.upcoming_release && train.backmerge_to_upcoming_release && !bot_commit?
      upcoming_release_pr = Triggers::PullRequest.new(
        release: release,
        new_pull_request: (commit.pull_requests.build(release:, phase: :ongoing) if commit.pull_requests.find_by(base_ref: train.upcoming_release.branch_name).blank?),
        to_branch_ref: train.upcoming_release.branch_name,
        from_branch_ref: patch_branch(train.upcoming_release.branch_name),
        title: pr_title,
        description: pr_description,
        existing_pr: commit.pull_requests.find_by(base_ref: train.upcoming_release.branch_name),
        patch_pr: true,
        patch_commit: commit
      )
      upcoming_release_pr.create_and_merge!
    end
  end

  private

  delegate :logger, to: Rails
  delegate :train, to: :release
  delegate :working_branch, to: :train
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

  def patch_branch(target_branch = working_branch)
    "patch-#{target_branch}-#{commit.short_sha}"
  end

  def bot_commit?
    commit.author_login == "tramline-github-dev[bot]"
  end
end
