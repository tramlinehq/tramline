# frozen_string_literal: true

class V2::LiveRelease::ReleaseCandidateComponent < V2::BaseReleaseComponent
  include Memery

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
    ci_workflow_failed: {text: "Workflow failure", status: :failure},
    ci_workflow_unavailable: {text: "Workflow not found", status: :failure},
    ci_workflow_halted: {text: "Workflow cancelled", status: :inert},
    build_unavailable: {text: "Build unavailable", status: :failure},
    deployment_failed: {text: "Deployment failed", status: :failure},
    failed_with_action_required: {text: "Needs manual submission", status: :failure},
    cancelling: {text: "Cancelling", status: :inert},
    cancelled: {text: "Cancelled", status: :inert},
    cancelled_before_start: {text: "Overwritten", status: :neutral}
  }

  def initialize(release)
    @release = release
    super(@release)

    @platform_run_components = release.release_platform_runs.map do |release_platform_run|
      V2::LiveRelease::BaseStepRunComponent.new(release_platform_run, kind: :release)
    end
  end

  attr_reader :release, :platform_run_components
end
