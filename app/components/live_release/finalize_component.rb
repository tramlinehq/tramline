# frozen_string_literal: true

class LiveRelease::FinalizeComponent < BaseComponent
  include Memery

  def initialize(release)
    @release = release
    @mid_release_backmerge_prs = release.mid_release_back_merge_prs
    @post_release_backmerge_prs = release.post_release_back_merge_prs
    @unmerged_commits = release.unmerged_commits
  end

  attr_reader :release, :unmerged_commits
  delegate :train, :finished?, :post_release_started?, :post_release_failed?, to: :release

  ICON_CLASSES = "align-text-bottom"
  SUCCESS_ICON_CLASSES = "#{ICON_CLASSES} text-green-600"
  FAILURE_ICON_CLASSES = "#{ICON_CLASSES} text-red-600"
  PENDING_ICON_CLASSES = "#{ICON_CLASSES} text-secondary animate-pulse"

  def status_icon(condition = nil)
    completed = condition.nil? ? automations_started? : condition

    if post_release_started? && condition.nil?
      return render(IconComponent.new("circle_dashed.svg", size: :md, classes: PENDING_ICON_CLASSES))
    end

    if completed
      render(IconComponent.new("circle_check_big.svg", size: :md, classes: SUCCESS_ICON_CLASSES))
    else
      render(IconComponent.new("circle_x.svg", size: :md, classes: FAILURE_ICON_CLASSES))
    end
  end

  memoize def automations_started?
    post_release_started? || post_release_failed? || finished?
  end

  def open_prs?
    post_release_failed? && (open_backmerge_prs? || open_post_release_prs?)
  end

  def wrap_up?
    post_release_failed? && !unmerged_commits?
  end

  memoize def open_backmerge_prs
    @mid_release_backmerge_prs.open
  end

  memoize def open_post_release_prs
    @post_release_backmerge_prs.open
  end

  memoize def closed_backmerge_prs
    @mid_release_backmerge_prs.closed
  end

  memoize def closed_post_release_prs
    @post_release_backmerge_prs.closed
  end

  def unmerged_commits?
    @unmerged_commits.present?
  end

  def open_backmerge_prs?
    open_backmerge_prs.present?
  end

  def open_post_release_prs?
    open_post_release_prs.present?
  end

  def title
    return "⚡️End-of-release automations" if release.finished?
    "⚡️Pending end-of-release automations"
  end

  def subtitle
    return "These will be automatically run when the rollout finishes" unless release.finished?
    ""
  end

  memoize def tag_enabled?
    train.tag_end_of_release?
  end

  memoize def tag_successful?
    tag_enabled? && release.tag_name.present?
  end

  memoize def backmerge_successful?
    return true if train.backmerge_strategy == "disabled"
    automations_started? && !unmerged_commits? && !open_backmerge_prs? && !open_post_release_prs?
  end

  def tag_link
    link = release.tag_url || release.app.vcs_provider&.code_repo_url
    return NOT_AVAILABLE if link.blank?
    link_to_external train.vcs_provider.display, link, class: "underline"
  end
end
