# frozen_string_literal: true

class LiveRelease::BuildComponent < BaseComponent
  include Memery

  WORKFLOW_STATUS = {
    created: {text: "Waiting", status: :inert},
    triggering: {text: "Preparing workflow", status: :ongoing, kind: :spinner_pill},
    triggered: {text: "Workflow started", status: :ongoing, kind: :spinner_pill},
    unavailable: {text: "Build unavailable", status: :failure},
    started: {text: "Workflow running", status: :ongoing, kind: :spinner_pill},
    failed: {text: "Workflow failed", status: :failure},
    halted: {text: "Workflow halted", status: :failure},
    finished: {text: "Workflow finished", status: :ongoing},
    cancelled: {text: "Workflow cancelled", status: :inert},
    cancelling: {text: "Cancelling the workflow", status: :ongoing, kind: :spinner_pill},
    cancelled_before_start: {text: "Workflow cancelled", status: :inert}
  }

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

  def build_time
    build.generated_at || build.updated_at
  end

  def build_time_tick?
    %w[triggering triggered started].include?(build.workflow_run.status)
  end

  def workflow_status
    status_picker(WORKFLOW_STATUS, build.workflow_run.status)
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
    "Originally created on #{time_format(build_time)}"
  end
end
