# frozen_string_literal: true

class V2::LiveRelease::SubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission, inactive: false)
    @submission = submission
    @inactive = inactive
  end

  attr_reader :submission, :inactive
  delegate :build, :release_platform_run, :external_link, to: :submission
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

  def commits_since_last
    changes&.normalized_commits
  end

  def previous_submission
    release_platform_run
      .production_releases
      .where("created_at < ?", submission.parent_release.created_at)
      .reorder("created_at DESC").first&.store_submission
  end

  memoize def changes
    submission.release.release_changelog
  end

  memoize def available_builds
    return all_builds unless build
    all_builds.where.not(id: build.id)
  end

  memoize def newer_builds
    return all_builds unless build
    all_builds.where("generated_at > ?", build.generated_at).where.not(id: build&.id)
  end

  memoize def all_builds
    release_platform_run.rc_builds.reorder("generated_at DESC")
  end

  def build_display_info(b)
    builder = b.display_name
    return "#{builder} – Currently Selected" if b == build
    builder += " – Latest" if release_platform_run.latest_rc_build?(b)
    builder
  end

  def active?
    !inactive
  end

  def changeable?
    active? && submission.change_allowed? && available_builds.present?
  end

  def prompt_change?
    active? && submission.change_allowed? && newer_builds.present?
  end

  def new_submission_allowed?
    active? && submission.locked? && newer_builds.present?
  end

  def action
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
end
