# frozen_string_literal: true

class V2::LiveRelease::SubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission, inactive: false)
    @submission = submission
    @inactive = inactive
  end

  attr_reader :submission
  delegate :active_release?, :release_platform_run, :external_link, to: :submission
  delegate :release, to: :release_platform_run

  STATUS = {
    created: {text: "Ready", status: :inert},
    preparing: {text: "Preparing", status: :ongoing},
    prepared: {text: "Ready for review", status: :ongoing},
    failed_prepare: {text: "Failed to prepare", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    approved: {text: "Review approved", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure},
    cancelled: {text: "Removed from review", status: :inert}
  }

  def status
    STATUS[submission.status.to_sym] || {text: submission.status.humanize, status: :neutral}
  end

  def store_status
    submission.store_status&.humanize || "N/A"
  end

  def store_icon
    "integrations/logo_#{submission.provider}.png"
  end

  memoize def available_builds
    release_platform_run.available_rc_builds(current_build)
  end

  memoize def newer_builds
    release_platform_run.available_rc_builds(current_build, only_new: true)
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
    submission.change_allowed? && available_builds.present?
  end

  def prompt_change?
    submission.change_allowed? && newer_builds.present?
  end

  def change_build_prompt
    return if newer_builds.blank?

    if submission.change_allowed?
      render(V2::AlertComponent.new(type: :info, title: "A new build #{newer_builds.last.display_name} is available. Change build to update the submission.", dismissible: true))
    elsif submission.cancellable?
      render(V2::AlertComponent.new(type: :info, title: "A new build #{newer_builds.last.display_name} is available. Cancel submission and restart.", dismissible: true))
    end
  end

  def new_submission_allowed?
    active_release? && submission.locked? && newer_builds.present?
  end

  def action
    return unless active_release?

    if submission.created?
      {scheme: :default,
       type: :button,
       label: "Prepare for review",
       options: prepare_release_path,
       turbo: false,
       html_options: {method: :patch,
                      params: {store_submission: {force: false}},
                      data: {turbo_method: :patch, turbo_confirm: "Are you sure about that?"}}}
    elsif submission.cancellable?
      {scheme: :danger,
       type: :button,
       label: "Cancel submission",
       options: cancel_path,
       turbo: false,
       html_options: {method: :patch,
                      data: {turbo_method: :patch, turbo_confirm: "Are you sure about that?"}}}
    end
  end

  def submit_for_review_path
    return submit_for_review_app_store_submission_path(submission.id) if submission.is_a? AppStoreSubmission
    raise "Unsupported submission type"
  end

  def update_path
    return app_store_submission_path(submission.id) if submission.is_a? AppStoreSubmission
    return play_store_submission_path(submission.id) if submission.is_a? PlayStoreSubmission
    raise "Unsupported submission type"
  end

  def prepare_release_path
    return prepare_app_store_submission_path(submission.id) if submission.is_a? AppStoreSubmission
    return prepare_play_store_submission_path(submission.id) if submission.is_a? PlayStoreSubmission
    raise "Unsupported submission type"
  end

  def cancel_path
    return cancel_app_store_submission_path(submission.id) if submission.is_a? AppStoreSubmission
    raise "Unsupported submission type"
  end

  def current_build
    submission.build
  end

  def build_opts
    options_for_select(all_builds.map { |b| [build_display_info(b), b.id] }, current_build.id)
  end
end
