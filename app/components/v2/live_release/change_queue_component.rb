class V2::LiveRelease::ChangeQueueComponent < V2::BaseComponent
  include Memery

  def initialize(release)
    @release = release
    @build_queue = release.active_build_queue
    @applied_commits = release.applied_commits.sequential.includes(step_runs: :step)
    @mid_release_prs = release.mid_release_prs.open
    @open_backmerge_prs = release.pull_requests.ongoing.open
    @change_queue_commits = @build_queue.commits.sequential
  end

  attr_reader :release, :build_queue, :applied_commits, :change_queue_commits, :mid_release_prs, :open_backmerge_prs

  def change_queue_commits_count = change_queue_commits.size
end
