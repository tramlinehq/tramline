class BackmergeCherryPickInstructionsComponent < BaseComponent
  def initialize(commit)
    @commit = commit
  end

  attr_reader :commit

  delegate :release, :short_sha, :commit_hash, to: :commit
  delegate :train, to: :release
  delegate :working_branch, to: :train

  INSTRUCTIONS = [
    {
      text: "Fetch the latest changes from the remote repository"
    },
    {
      text: "Create a new patch branch from the working branch",
      note: "Skip to step 3, if you'd like to cherry-pick directly on the working branch"
    },
    {
      text: "Apply this commit to your working branch"
    },
    {
      text: "Push the changes to the remote repository"
    }
  ].freeze

  def instructions
    INSTRUCTIONS.zip(commands).map do |instruction, command|
      instruction.merge(command:)
    end
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
