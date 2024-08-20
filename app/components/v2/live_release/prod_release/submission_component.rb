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
  delegate :id, :inflight?, :actionable?, :release_platform_run, :external_link, :provider, to: :submission
  delegate :release, to: :release_platform_run

  def inflight? = submission.parent_release.inflight?

  def blocked?
    release.blocked_for_production_release?
  end

  def inactive? = @inactive

  def before_render
    compute_prompts
    super
  end

  def blocked_release_link
    if release.ongoing?
      hotfix_release_app_train_releases_path(release.train.app, release.train)
    else
      ongoing_release_app_train_releases_path(release.train.app, release.train)
    end
  end

  def blocked_release_link_text
    release.ongoing? ? "current hotfix release" : "current ongoing release"
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

  memoize def available_builds
    release_platform_run.available_rc_builds
  end

  memoize def newer_builds
    release_platform_run.available_rc_builds(after: current_build)
  end

  def all_builds
    available_builds + [current_build]
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
    elsif !@inactive
      @new_submission_prompt = true
    end
  end

  def action
    return if blocked?
    return unless actionable?

    if submission.created?
      message = "You are about to prepare the submission for review.\nAre you sure?"
      {scheme: :default,
       type: :button,
       label: "Prepare for review",
       options: prepare_store_submission_path(id),
       turbo: false,
       html_options: html_opts(:patch, message, params: {store_submission: {force: false}})}
    elsif submission.cancellable?
      message = "You are about to cancel the submission.\nAre you sure?"
      {scheme: :danger,
       type: :button,
       label: "Cancel submission",
       options: cancel_store_submission_path(id),
       turbo: false,
       html_options: html_opts(:patch, message)}
    end
  end

  def current_build
    submission.build
  end

  def build_opts(default: nil)
    options_for_select(all_builds.map { |b| [build_display_info(b), b.id] }, default.presence || all_builds.first)
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