# frozen_string_literal: true

class V2::LiveRelease::BuildComponent < V2::BaseComponent
  include Memery

  def initialize(build, show_number: false, show_build_only: false, show_metadata: true, show_ci: true, show_activity: true, show_commit: true)
    @build = build
    @show_number = show_number
    @show_metadata = show_metadata
    @show_ci = show_ci
    @show_activity = show_activity
    @show_commit = show_commit
  end

  attr_reader :build, :previous_build, :show_build_only, :show_number, :show_metadata, :show_ci, :show_activity, :show_commit
  delegate :release_platform_run, :commit, :version_name, :artifact, :workflow_run, to: :build
  delegate :external_url, :external_number, to: :workflow_run

  def badge_data?
    show_number || show_ci || show_activity
  end

  def build_info
    build.display_name
  end

  def ci_info
    "Build ##{external_number}"
  end

  # TODO: [V2] fix this
  def ci_link
    external_url
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

  def last_activity_at
    ago_in_words(build.updated_at)
  end

  def number
    build.sequence_number
  end

  def build_number
    build.build_number || NOT_AVAILABLE
  end

  def artifact_name
    return NOT_AVAILABLE if artifact.blank?
    artifact.get_filename
  end

  def created_tooltip
    "Originally created on #{time_format(build.generated_at)}"
  end
end
