# frozen_string_literal: true

class V2::LiveRelease::BuildComponent < V2::BaseComponent
  include Memery

  def initialize(build, show_number: true, show_metadata: true, show_ci: true, show_activity: true, show_commit: true, show_compact_metadata: false)
    @build = build
    @show_number = show_number
    @show_metadata = show_metadata
    @show_ci = show_ci
    @show_activity = show_activity
    @show_commit = show_commit
    @show_compact_metadata = show_compact_metadata
  end

  attr_reader :build, :previous_build, :show_number, :show_metadata, :show_ci, :show_activity, :show_commit, :show_compact_metadata
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

  def build_logo
    "integrations/logo_#{build.ci_cd_provider}.png"
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
