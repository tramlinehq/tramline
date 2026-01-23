class LiveRelease::ChangesetTrackingComponent < BaseComponent
  include Memery

  def initialize(release)
    @release = release
    @build_queue = release.active_build_queue
    @applied_commits = release.applied_commits.sequential
    @mid_release_stability_prs = release.mid_release_stability_prs.open
    @open_backmerge_prs = release.mid_release_back_merge_prs.open
    @change_queue_commits = @build_queue&.commits&.sequential
    @version_bump_prs = release.pull_requests.version_bump_type
  end

  attr_reader :release, :build_queue, :applied_commits, :change_queue_commits, :mid_release_stability_prs, :open_backmerge_prs, :version_bump_prs

  def change_queue_commits_count
    change_queue_commits&.size || 0
  end

  def changelog_present?
    @release.release_changelog.present?
  end

  memoize def commits_since_last
    @release.release_changelog&.commits
  end

  def changelog_from
    @release.release_changelog.from_ref
  end

  def apply_help_text
    return if change_queue_commits.blank?
    "#{change_queue_commits_count} commit(s) in the queue. These will be automatically applied in #{time_in_words(build_queue&.scheduled_at)} or after #{build_queue&.build_queue_size} commits."
  end

  memoize def conflicting_branch_releases
    @release.conflicting_branch_releases
  end

  def conflicting_branch_release_links
    safe_join(
      conflicting_branch_releases.map do |r|
        link_to_external(r.slug, release_path(r), class: "font-mono underline")
      end,
      ", "
    )
  end
end
