# frozen_string_literal: true

class V2::LiveRelease::BuildComponent < V2::BaseComponent
  include Memery

  STATUS = {
    created: {text: "Ready", status: :inert},
    preparing: {text: "Preparing", status: :ongoing},
    prepared: {text: "Ready for review", status: :ongoing},
    failed_prepare: {text: "Failed to prepare", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    approved: {text: "Review approved", status: :ongoing},
    failed: {text: "Failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure}
  }

  def initialize(build, previous_build: nil)
    @build = build
    @previous_build = previous_build
    @show_ci_info = show_ci_info
  end

  attr_reader :show_ci_info, :build, :previous_build
  delegate :release_platform_run, :store_submission, :commit, to: :build
  delegate :store_link, to: :store_submission, allow_nil: true

  def build_info
    build.display_name
  end

  def ci_info
    commit.short_sha
  end

  # FIXME
  def ci_link
    commit.url
  end

  def build_logo
    "integrations/logo_#{release_platform_run.release.train.ci_cd_provider}.png"
  end

  def commits_since_last_release
    return unless previous_build
    release_platform_run.all_commits.between_commits(previous_build&.commit, commit)
  end

  def diff_between
    return unless previous_build
    "#{previous_build.display_name} → #{build.display_name}"
  end

  def submission?
    store_submission.present?
  end

  def store_logo
    "integrations/logo_#{store_submission.integration_type}.png"
  end

  def status
    STATUS[store_submission.status.to_sym] || {text: "Unknown", status: :neutral}
  end

  def last_activity_at
    ago_in_words(store_submission&.updated_at || build.updated_at)
  end
end
