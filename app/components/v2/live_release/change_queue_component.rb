class V2::LiveRelease::ChangeQueueComponent < V2::BaseComponent
  include Memery
  def initialize(release, title:)
    @release = release
    @title = title
    @build_queue = release.active_build_queue
    @applied_commits = release.applied_commits.sequential.includes(step_runs: :step)
    @mid_release_prs = release.mid_release_prs
    @open_backmerge_prs = release.pull_requests.ongoing.open
    @change_queue_commits = @build_queue.commits.sequential
  end

  attr_reader :release, :build_queue, :title, :applied_commits, :change_queue_commits, :mid_release_prs, :open_backmerge_prs

  def change_queue_commits_count = change_queue_commits.size

  def change_queue_message
    msg = "#{change_queue_commits.size} commit(s) in the queue."
    msg += " These will be applied in #{time_in_words(build_queue.scheduled_at)} or after #{build_queue.build_queue_size} commits." if change_queue_commits_count > 0
    msg
  end
end
