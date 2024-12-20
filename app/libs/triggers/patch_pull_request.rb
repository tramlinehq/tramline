class Triggers::PatchPullRequest
  def self.create!(release, commit)
    new(release, commit).create!
  end

  delegate :train, to: :release
  delegate :working_branch, to: :train

  def initialize(release, commit)
    @release = release
    @commit = commit
    @pull_request = Triggers::PullRequest.new(
      release: release,
      new_pull_request: commit.build_pull_request(release:, phase: :ongoing),
      to_branch_ref: working_branch,
      from_branch_ref: patch_branch,
      title: pr_title,
      description: pr_description,
      existing_pr: commit.pull_request,
      patch_pr: true,
      enable_auto_merge: true
    )
  end

  def create!
    @pull_request.create_and_merge!
  end

  def create!
    GitHub::Result.new do
      repo_integration.create_patch_pr!(working_branch, patch_branch, commit.commit_hash, pr_title, pr_description)
    rescue Installations::Error => ex
      raise ex unless ex.reason == :pull_request_already_exists
      logger.debug { "Patch Pull Request: Pull Request Already exists for #{commit.short_sha} to #{working_branch}" }
      repo_integration.find_pr(working_branch, patch_branch)
    end.then do |value|
      pr = commit.build_pull_request(release:, phase: :ongoing).update_or_insert!(**value)
      repo_integration.enable_auto_merge!(pr.number)
      stamp_pr_create_success(pr)
      GitHub::Result.new { value }
    end
  end

  def merge!(pr)
    GitHub::Result.new do
      repo_integration.merge_pr!(pr.number)
      pr.close!
      stamp_pr_merge_success(pr)
      pr
    end
  end

  private

  delegate :logger, to: Rails
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

  def patch_branch
    "patch-#{working_branch}-#{commit.short_sha}"
  end

  def stamp_pr_create_success(pr)
    if pr
      release.event_stamp!(
        reason: :backmerge_pr_created,
        kind: :success,
        data: {url: pr.url, number: pr.number, commit_url: commit.url, commit_sha: commit.short_sha})

      logger.debug { "Patch Pull Request: Created a patch PR successfully: #{pr}" }
    end
  end

  def stamp_pr_merge_success(pr)
    if pr
      release.event_stamp!(
        reason: :backmerge_pr_created,
        kind: :success,
        data: {url: pr.url, number: pr.number, commit_url: commit.url, commit_sha: commit.short_sha})

      logger.debug { "Patch Pull Request: Merged a patch PR successfully: #{pr}" }
    end
  end

  def repo_integration = train.vcs_provider
end
