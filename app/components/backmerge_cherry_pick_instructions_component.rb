class BackmergeCherryPickInstructionsComponent < BaseComponent
  def initialize(commit)
    @commit = commit
  end

  attr_reader :commit

  delegate :release, :short_sha, :commit_hash, to: :commit
  delegate :train, to: :release
  delegate :working_branch, to: :train

  INSTRUCTIONS = [
    "Fetch the latest changes from the remote repository",
    "Switch to your working branch",
    "Apply this commit to your working branch",
    "Push the changes to the remote repository"
  ].freeze

  def instructions
    INSTRUCTIONS.zip(commands)
  end

  def commands
    [
      "git fetch origin",
      "git checkout -b patch-#{short_sha} origin/#{working_branch}",
      "git cherry-pick #{commit_hash}",
      "git push -u origin patch-#{short_sha}"
    ]
  end
end
