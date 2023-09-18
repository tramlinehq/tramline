class LiveRelease::CommitsComponent < ViewComponent::Base
  include ApplicationHelper
  include AssetsHelper

  def initialize(commits)
    @commits = commits
  end

  def commit_count
    commits.size
  end

  def commit_number(index)
    commit_count - index
  end

  attr_reader :commits, :release
end
