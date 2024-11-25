class Triggers::PatchPullRequest
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
      repo_integration.create_patch_pr!(working_branch, patch_branch, commit.commit_hash, pr_title, pr_description)
    rescue Installations::Error => ex
      raise ex unless ex.reason == :pull_request_already_exists
      logger.debug { "Patch Pull Request: Pull Request Already exists for #{commit.short_sha} to #{working_branch}" }
      repo_integration.find_pr(working_branch, patch_branch)
    end.then do |value|
      pr = commit.build_pull_request(release:, phase: :ongoing).update_or_insert!(**value)
      logger.debug { "Patch Pull Request: Created a patch PR successfully: #{pr}" }
      repo_integration.enable_auto_merge!(pr.number)
      stamp_pr_success(pr)
      GitHub::Result.new { value }
    end
  end

  private

  delegate :logger, to: Rails
  attr_reader :release, :commit

  def pr_title
    "[PATCH] [#{release.release_version}] #{commit.message.split("\n").first}".gsub(/\s*\(#\d+\)/, "").squish
  end

  def pr_description
    authored_by = commit.author_login.present? ? "@#{commit.author_login}" : commit.author_email
    <<~TEXT
      - Cherry-pick #{commit.commit_hash} commit
      - Authored by: #{authored_by}

      #{commit.message}
    TEXT
  end

  def patch_branch
    "patch-#{working_branch}-#{commit.short_sha}"
  end

  def stamp_pr_success(pr)
    release.event_stamp!(reason: :backmerge_pr_created, kind: :success, data: {url: pr.url, number: pr.number, commit_url: commit.url, commit_sha: commit.short_sha}) if pr
  end

  def repo_integration
    train.vcs_provider
  end
end
