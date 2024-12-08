# frozen_string_literal: true

class V2::LiveRelease::ProdRelease::SubmissionComponent < V2::BaseComponent
  include Memery

  STATUS = {
    created: {text: "Not started", status: :inert},
    preprocessing: {text: "Processing", status: :ongoing},
    preparing: {text: "Processing", status: :ongoing},
    prepared: {text: "Ready for review", status: :ongoing},
    failed_prepare: {text: "Failed to prepare", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    approved: {text: "Review approved", status: :ongoing},
    failed: {text: "Submission failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure},
    cancelled: {text: "Removed from review", status: :inert},
    finished: {text: "Submitted", status: :success}
  }

  def initialize(submission, inactive: false, title: "Store Submission")
    @submission = submission
    @inactive = inactive
    @change_build_prompt = false
    @cancel_prompt = false
    @blocked_notice = false
    @new_submission_prompt = false
    @title = title
  end

  attr_reader :submission
  delegate :id, :inflight?, :release_platform_run, :external_link, :provider, to: :submission
  delegate :release, to: :release_platform_run

  def show_blocked_message?
    release_platform_run.play_store_blocked? && !submission.failed_with_action_required?
  end

  def inflight? = submission.parent_release.inflight?

  def blocked?
    release.blocked_for_production_release?
  end

  def actionable?
    return false if cascading_rollout_actionable?
    submission.actionable?
  end

  def inactive? = @inactive

  def before_render
    compute_prompts
    super
  end

  memoize def blocked_release_info
    train = release.train
    app = train.app

    if release.upcoming?
      return {
        message: "You cannot start this submission until the current ongoing release is finished.",
        info: {label: "Go to the blocking release", link: ongoing_release_app_train_releases_path(app, train)}
      }
    end

    if release.ongoing? && train.hotfix_release.present?
      return {
        message: "You cannot start this submission until the current hotfix release is finished.",
        info: {label: "Go to the blocking release", link: hotfix_release_app_train_releases_path(app, train)}
      }
    end

    if release.approvals_blocking?
      return {
        message: "You cannot start this submission until all the approvals are completed.",
        info: {label: "Go to approvals", link: release_approval_items_path(release)}
      }
    end

    nil
  end

  def status
    return STATUS[:finished] if submission.finished?
    status_picker(STATUS, submission.status).merge(kind: :status)
  end

  def store_status
    submission.store_status&.humanize || NOT_AVAILABLE
  end

  def store_icon
    "integrations/logo_#{submission.provider}.png"
  end

  def submission_logo_bw
    "v2/logo_#{submission.provider}_bw.svg"
  end

  memoize def available_builds
    release_platform_run.available_rc_builds
  end

  memoize def newer_builds
    release_platform_run.available_rc_builds(after: current_build)
  end

  def all_builds
    (available_builds + [current_build]).sort_by(&:generated_at).reverse
  end

  def build_display_info(b)
    builder = b.display_name
    return "#{builder} – Currently Selected" if b == current_build
    builder += " – Latest" if release_platform_run.latest_rc_build?(b)
    builder
  end

  def changeable?
    return false if blocked?
    submission.change_build? && available_builds.present?
  end

  def compute_prompts
    return @blocked_notice = true if blocked?
    return if newer_builds.blank?

    if submission.change_build?
      @change_build_prompt = true
    elsif submission.cancellable?
      @cancel_prompt = true
    elsif !@inactive && !submission.cancelling?
      @new_submission_prompt = true
    end
  end

  # rubocop:disable Rails/Delegate
  memoize def previously_completed_rollout_run
    release_platform_run.previously_completed_rollout_run
  end

  memoize def previously_completed_release
    previously_completed_rollout_run&.release
  end
  # rubocop:enable Rails/Delegate

  memoize def cascading_rollout_actionable?
    submission.created? && submission.finish_rollout_in_next_release? && previously_completed_rollout_run.present?
  end

  def previously_completed_release_link
    release_store_rollouts_path(previously_completed_release)
  end

  def action
    if submission.created?
      message = "You are about to prepare the submission for review.\nAre you sure?"
      {scheme: :default,
       type: :button,
       label: "Prepare for review",
       disabled: !actionable?,
       options: prepare_store_submission_path(id),
       html_options: html_opts(:patch, message, params: {store_submission: {force: false}})}
    elsif submission.cancellable?
      message = "You are about to cancel the submission.\nAre you sure?"
      {scheme: :danger,
       type: :button,
       label: "Cancel submission",
       disabled: !actionable?,
       options: cancel_store_submission_path(id),
       html_options: html_opts(:patch, message)}
    end
  end

  def current_build
    submission.build
  end

  def build_opts(default: nil)
    options_for_select(all_builds.map { |b| [build_display_info(b), b.id] }, (default.presence || all_builds.first).id)
  end

  def border_style
    :dashed if inflight?
  end

  # ============== Sandbox actions ==============
  def mock_actions
    return unless actionable? && submission.respond_to?(:submitted_for_review?) && submission.submitted_for_review?

    content_tag(:div, class: "flex items-center gap-0.5") do
      concat(render(V2::ButtonComponent.new(scheme: :mock,
        type: :button,
        label: "Mock approve",
        options: mock_approve_for_app_store_path(submission.id),
        turbo: false,
        html_options: html_opts(:patch, "Are you sure about that?"))))
      concat(render(V2::ButtonComponent.new(scheme: :mock,
        type: :button,
        label: "Mock reject",
        options: mock_reject_for_app_store_path(submission.id),
        turbo: false,
        html_options: html_opts(:patch, "Are you sure about that?"))))
    end
  end
end
