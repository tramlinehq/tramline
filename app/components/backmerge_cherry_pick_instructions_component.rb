class BackmergeCherryPickInstructionsComponent < BaseComponent
  def initialize(commit)
    @commit = commit
  end

  attr_reader :commit

  delegate :release, :short_sha, to: :commit
  delegate :train, to: :release
  delegate :working_branch, to: :train

  def commands_with_descriptions
    commands.zip(step_descriptions)
  end

  private

  def commands
    [
      "git fetch origin",
      "git checkout -b patch-#{short_sha} #{working_branch}",
      "git cherry-pick #{short_sha}",
      "git push -u origin patch-#{short_sha}"
    ]
  end

  def step_descriptions
    [
      "Fetch the latest changes from the remote repository",
      "Switch to your working branch",
      "Apply this commit to your working branch",
      "Push the changes to the remote repository"
    ]
  end
end
