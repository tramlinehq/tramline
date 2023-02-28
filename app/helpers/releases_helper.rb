module ReleasesHelper
  include ApplicationHelper
  include Memery

  SHOW_RELEASE_STATUS = {
    finished: ["Completed", :success],
    stopped: ["Stopped", :inert],
    on_track: ["Running", :ongoing],
    post_release: ["Finalizing", :neutral],
    post_release_started: ["Finalizing", :neutral],
    post_release_failed: ["Finalizing", :neutral]
  }

  def release_status_badge(status)
    status, styles = SHOW_RELEASE_STATUS.fetch(status.to_sym)
    status_badge(status, styles)
  end

  def build_status_badge(step_run)
    status, styles =
      case step_run.status.to_sym
      when :ci_workflow_triggered, :on_track
        ["Waiting for CI", :routine]
      when :ci_workflow_started
        ["In progress", :ongoing]
      when :build_ready
        ["Looking for build to deploy", :ongoing]
      when :deployment_started
        ["Deployments in progress", :ongoing]
      when :build_found_in_store
        ["Build found in store", :routine]
      when :build_not_found_in_store
        ["Build not found in store", :failure]
      when :success
        ["Success", :success]
      when :ci_workflow_failed
        ["CI workflow failure", :failure]
      when :ci_workflow_unavailable
        ["CI workflow not found", :failure]
      when :ci_workflow_halted
        ["CI workflow cancelled", :inert]
      when :build_unavailable
        ["Build unavailable", :failure]
      when :deployment_failed
        ["Deployment failed", :failure]
      else
        ["Unknown", :neutral]
      end

    status_badge(status, styles)
  end

  def deployment_run_status_badge(deployment_run)
    status, styles =
      case deployment_run.status.to_sym
      when :created
        ["About to start", :inert]
      when :started
        ["Running", :ongoing]
      when :prepared_release
        ["Ready for review", :ongoing]
      when :submitted
        ["Submitted for review", :ongoing]
      when :ready_to_release
        ["Review approved", :ongoing]
      when :uploaded
        ["Uploaded", :routine]
      when :upload_failed
        ["Upload failed", :failure]
      when :rollout_started
        ["In Staged Rollout", :routine]
      when :released
        ["Released", :success]
      when :failed
        ["Failed", :failure]
      else
        ["Unknown", :neutral]
      end

    status_badge(status, styles)
  end

  def pull_request_badge(pull_request)
    style =
      case pull_request.state.to_sym
      when :open
        :success
      when :closed
        :ongoing
      else
        :neutral
      end

    status_badge(pull_request.state, style)
  end
end
