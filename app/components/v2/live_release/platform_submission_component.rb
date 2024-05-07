# frozen_string_literal: true

class V2::LiveRelease::PlatformSubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission)
    @submission = submission
  end

  attr_reader :submission
  delegate :build, :release_platform_run, to: :submission
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
    cancelled: {text: "Review cancelled", status: :inert}
  }

  def status
    STATUS[submission.status.to_sym] || {text: submission.status.humanize, status: :neutral}
  end

  def commits_since_last
    changes&.normalized_commits
  end

  memoize def changes
    submission.release.release_changelog
  end

  memoize def available_builds
    all_builds.where.not(id: build&.id)
  end

  memoize def newer_builds
    all_builds.where("generated_at > ?", build.generated_at).where.not(id: build&.id)
  end

  memoize def all_builds
    release_platform_run.builds.reorder("generated_at DESC")
  end

  def build_display_info(b)
    builder = b.display_name
    return "#{builder} – Currently Selected" if b == build
    builder += " – Latest" if release_platform_run.latest_build?(b)
    builder
  end

  def changeable?
    submission.change_allowed? && !submission.cancellable? && available_builds.present?
  end

  def action
    return unless submission.startable?

    if submission.created?
      {scheme: :default,
       type: :button,
       size: :xxs,
       label: "Prepare for review",
       options: prepare_release_platform_store_submission_path(release, release_platform_run.platform, submission.id),
       turbo: false,
       html_options: {method: :patch,
                      params: {store_submission: {force: false}},
                      data: {turbo_method: :patch, turbo_confirm: "Are you sure about that?"}}}
    elsif submission.reviewable?
      {scheme: :default,
       type: :button,
       size: :xxs,
       label: "Submit for review",
       options: submit_for_review_release_platform_store_submission_path(release, release_platform_run.platform, submission.id),
       turbo: false,
       html_options: {method: :patch, data: {turbo_method: :patch, turbo_confirm: "Are you sure about that?"}}}
    elsif submission.cancellable?
      {scheme: :danger,
       type: :button,
       size: :xxs,
       label: "Cancel submission",
       options: cancel_release_platform_store_submission_path(release, release_platform_run.platform, submission.id),
       turbo: false,
       html_options: {method: :patch,
                      data: {turbo_method: :patch, turbo_confirm: "Are you sure about that?"}}}
    end
  end
end
