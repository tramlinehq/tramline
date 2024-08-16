# frozen_string_literal: true

class V2::LiveRelease::FinalizeComponent < V2::BaseComponent
  include Memery

  def initialize(release)
    @release = release
  end

  attr_reader :release
  delegate :post_release_prs,
    :backmerge_prs,
    :unmerged_commits,
    :finished?,
    :post_release_started?,
    :post_release_failed?, to: :release

  def strikethrough
    "line-through" if strikethrough?
  end

  def checked
    "✅" if strikethrough?
  end

  def strikethrough?
    finished? || post_release_failed? || post_release_started?
  end

  memoize def unmerged_changes
    unmerged_commits
  end

  memoize def open_backmerge_prs
    backmerge_prs.open
  end

  memoize def open_post_release_prs
    post_release_prs.open
  end

  def unmerged_changes?
    unmerged_changes.present?
  end

  def open_backmerge_prs?
    open_backmerge_prs.present?
  end

  def open_post_release_prs?
    open_post_release_prs.present?
  end

  def closed_backmerge_prs
    release.backmerge_prs.closed
  end

  def closed_post_release_prs
    release.post_release_prs.closed
  end

  def completable?
    post_release_failed? && !open_backmerge_prs? && !open_post_release_prs?
  end

  def title
    return "⚡️End-of-release task summary" if release.finished?
    "⚡️Pending End-of-release tasks"
  end

  def subtitle
    return "These will be automatically run when the rollout finishes" unless release.finished?
    ""
  end
end
