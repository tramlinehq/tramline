# frozen_string_literal: true

class V2::LiveRelease::PlatformSubmissionComponent < V2::BaseComponent
  include Memery

  def initialize(submission)
    @submission = submission
  end

  attr_reader :submission
  delegate :build, :release_platform_run, to: :submission
  delegate :release, to: :release_platform_run

  def commits_since_last
    changes&.normalized_commits
  end

  memoize def changes
    submission.release.release_changelog
  end

  memoize def available_builds
    all_builds.where.not(id: submission.build&.id)
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
    end
  end
end
