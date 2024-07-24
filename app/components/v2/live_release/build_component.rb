# frozen_string_literal: true

class V2::LiveRelease::BuildComponent < V2::BaseComponent
  include Memery

  def initialize(build, show_number: false, show_build_only: false)
    @build = build
    @show_number = show_number
    @show_build_only = show_build_only
  end

  attr_reader :build, :previous_build, :show_build_only, :show_number
  delegate :release_platform_run, :store_submission, :commit, :version_name, :build_number, :artifact, :workflow_run, to: :build
  delegate :external_url, to: :workflow_run

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
    "integrations/logo_#{store_submission.provider}.png"
  end

  def last_activity_at
    ago_in_words(store_submission&.updated_at || build.updated_at)
  end

  def number
    "Build ##{rand(50..998)}"
  end

  def artifact_name
    return "-" if artifact.blank?
    artifact.get_filename
  end
end
