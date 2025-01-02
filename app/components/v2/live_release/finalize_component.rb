# frozen_string_literal: true

class V2::LiveRelease::FinalizeComponent < V2::BaseComponent
  include Memery

  def initialize(release)
    @release = release
  end

  attr_reader :release
  delegate :post_release_prs,
    :train,
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
    post_release_started? || post_release_failed? || finished?
  end

  def open_prs?
    post_release_failed? && (open_backmerge_prs? || open_post_release_prs?)
  end

  def wrap_up?
    post_release_failed? && !unmerged_changes?
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

  def title
    return "⚡️End-of-release automations" if release.finished?
    "⚡️Pending end-of-release automations"
  end

  def subtitle
    return "These will be automatically run when the rollout finishes" unless release.finished?
    ""
  end

  def tag_link
    link = release.tag_url || release.app.config.code_repo_url
    link_to_external train.vcs_provider.display, link, class: "underline"
  end
end
