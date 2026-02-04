class BackmergeCherryPickInstructionsComponent < BaseComponent
  def initialize(commit)
    @commit = commit
  end

  attr_reader :commit

  def working_branch
    commit.release.train.working_branch
  end

  def release_branch
    commit.release.branch_name
  end

  delegate :short_sha, to: :commit

  def commands
    [
      "git fetch origin",
      "git checkout -b patch-#{short_sha} #{working_branch}",
      "git cherry-pick #{short_sha}",
      "git push -u origin patch-#{short_sha}"
    ]
  end
end
