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

  def commits_toggle
    toggle_for(false, full_width: true) do
      content_tag(:span,
        "commits (#{commit_count})",
        class: "text-xs font-semibold uppercase text-slate-500")
    end
  end

  attr_reader :commits, :release
end
