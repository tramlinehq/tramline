# frozen_string_literal: true

class V2::LiveRelease::InternalBuildComponent < V2::BaseComponent
  include Memery

  DEPLOYMENT_STATUS = {
    created: {text: "About to start", status: :inert},
    started: {text: "Running", status: :ongoing},
    preparing_release: {text: "Preparing store version", status: :ongoing},
    prepared_release: {text: "Ready for review", status: :ongoing},
    failed_prepare_release: {text: "Failed to start release", status: :inert},
    submitted_for_review: {text: "Submitted for review", status: :inert},
    review_failed: {text: "Review rejected", status: :failure},
    ready_to_release: {text: "Review approved", status: :ongoing},
    uploading: {text: "Uploading", status: :neutral},
    uploaded: {text: "Uploaded", status: :ongoing},
    rollout_started: {text: "Rollout started", status: :ongoing},
    released: {text: "Released", status: :success},
    failed: {text: "Failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure}
  }

  STEP_STATUS = {
    on_track: {text: "Waiting for CI", status: :routine},
    ci_workflow_triggered: {text: "Waiting for CI", status: :routine},
    ci_workflow_started: {text: "In progress", status: :ongoing},
    build_ready: {text: "Looking for build to deploy", status: :ongoing},
    deployment_started: {text: "Deployments in progress", status: :ongoing},
    deployment_restarted: {text: "Deployments in progress", status: :ongoing},
    build_found_in_store: {text: "Build found in store", status: :routine},
    build_not_found_in_store: {text: "Build not found in store", status: :failure},
    success: {text: "Success", status: :success},
    ci_workflow_failed: {text: "CI workflow failure", status: :failure},
    ci_workflow_unavailable: {text: "CI workflow not found", status: :failure},
    ci_workflow_halted: {text: "CI workflow cancelled", status: :inert},
    build_unavailable: {text: "Build unavailable", status: :failure},
    deployment_failed: {text: "Deployment failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure},
    cancelling: {text: "Cancelling", status: :inert},
    cancelled: {text: "Cancelled", status: :inert},
    cancelled_before_start: {text: "Overwritten", status: :neutral}
  }

  def initialize(step_run:, release_platform_run:, compact: false)
    @step_run = step_run
    @release_platform_run = release_platform_run
    @compact = compact
  end

  attr_reader :step_run, :release_platform_run
  delegate :step, :release, to: :step_run

  def compact?
    @compact
  end

  memoize def commits_since_last_step_run
    previous_step_run = release_platform_run.previous_successful_run_before(step_run)
    return unless previous_step_run
    release_platform_run.commits_between(previous_step_run, step_run)
  end

  def step_status
    STEP_STATUS[step_run.status.to_sym] || {text: step_run.status.humanize, status: :neutral}
  end

  def deployment_status(deployment_run)
    DEPLOYMENT_STATUS[deployment_run.status.to_sym] || {text: deployment_run.status.humanize, status: :neutral}
  end

  def download_build
    return if step_run.download_url.blank?

    render V2::ButtonComponent.new(scheme: compact? ? :naked_icon : :supporting,
      label: compact? ? nil : "Download build",
      type: :link_external,
      options: step_run.download_url,
      authz: false,
      size: :none) do |b|
      b.with_icon("v2/download.svg", size: :md)
      b.with_tooltip("Download build", placement: "top")
    end
  end
end
