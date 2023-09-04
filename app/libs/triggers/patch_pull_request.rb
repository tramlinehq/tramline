class Triggers::PatchPullRequest
  class CreateError < StandardError; end

  def self.create!(release, commit)
    new(release, commit).create!
  end

  delegate :train, to: :release
  delegate :working_branch, to: :train

  def initialize(release, commit)
    @release = release
    @commit = commit
  end

  def create!
    GitHub::Result.new do
      repo_integration.create_patch_pr!(working_branch, patch_branch, commit.commit_hash, pr_title_prefix)
    rescue Installations::Errors::PullRequestAlreadyExists
      logger.debug("Patch Pull Request: Pull Request Already exists for #{commit.short_sha} to #{working_branch}")
      repo_integration.find_pr(working_branch, patch_branch)
    end.then do |value|
      pr = commit.pull_requests.ongoing.build(release:).update_or_insert!(**value)
      logger.debug "Patch Pull Request: Created a patch PR successfully", pr
      stamp_pr_success
      GitHub::Result.new { value }
    end
  end

  private

  delegate :logger, to: Rails
  attr_reader :release, :commit

  def patch_branch
    "patch-#{working_branch}-#{commit.short_sha}"
  end

  def pr_title_prefix
    "[PATCH] [#{release.release_version}]"
  end

  def stamp_pr_success
    # pr = release.reload.pull_requests.ongoing.first
    # release.event_stamp!(reason: :mid_release_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number}) if pr
  end

  def repo_integration
    train.vcs_provider
  end
end
