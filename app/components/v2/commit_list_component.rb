class V2::CommitListComponent < V2::BaseComponent
  def initialize(commits)
    @commits = commits
  end

  attr_reader :commits
end
