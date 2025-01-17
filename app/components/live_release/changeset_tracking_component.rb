class LiveRelease::ChangesetTrackingComponent < BaseComponent
  include Memery

  def initialize(release)
    @release = release
    @build_queue = release.active_build_queue
    @applied_commits = release.applied_commits.sequential
    @mid_release_prs = release.mid_release_prs.open
    @open_backmerge_prs = release.pull_requests.ongoing.open
    @change_queue_commits = @build_queue&.commits&.sequential
  end

  attr_reader :release, :build_queue, :applied_commits, :change_queue_commits, :mid_release_prs, :open_backmerge_prs

  def change_queue_commits_count
    change_queue_commits&.size || 0
  end

  def changelog_present?
    @release.release_changelog.present?
  end

  memoize def commits_since_last
    @release.release_changelog&.normalized_commits
  end

  def changelog_from
    @release.release_changelog.from_ref
  end

  def apply_help_text
    return if change_queue_commits.blank?
    "#{change_queue_commits_count} commit(s) in the queue. These will be automatically applied in #{time_in_words(build_queue&.scheduled_at)} or after #{build_queue&.build_queue_size} commits."
  end
end
