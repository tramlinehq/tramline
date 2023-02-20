module ReleasesHelper
  include ApplicationHelper
  include Memery

  SHOW_RELEASE_STATUS = {
    finished: ["Completed", STATUS_COLOR_PALETTE[:success]],
    stopped: ["Stopped", STATUS_COLOR_PALETTE[:inert]],
    on_track: ["Running", STATUS_COLOR_PALETTE[:ongoing]],
    post_release: ["Finalizing", STATUS_COLOR_PALETTE[:neutral]],
    post_release_started: ["Finalizing", STATUS_COLOR_PALETTE[:neutral]],
    post_release_failed: ["Finalizing", STATUS_COLOR_PALETTE[:neutral]]
  }

  def release_status_badge(status)
    status, styles = SHOW_RELEASE_STATUS.fetch(status.to_sym)
    status_badge(status, styles)
  end

  def build_status_badge(step_run)
    status, styles =
      case step_run.status.to_sym
      when :ci_workflow_triggered, :on_track
        ["Waiting for CI", STATUS_COLOR_PALETTE[:routine]]
      when :ci_workflow_started
        ["In progress", STATUS_COLOR_PALETTE[:ongoing]]
      when :build_ready
        ["Looking for build to deploy", STATUS_COLOR_PALETTE[:ongoing]]
      when :deployment_started
        ["Deployments in progress", STATUS_COLOR_PALETTE[:ongoing]]
      when :build_found_in_store
        ["Build found in store", STATUS_COLOR_PALETTE[:routine]]
      when :build_not_found_in_store
        ["Build not found in store", STATUS_COLOR_PALETTE[:failure]]
      when :success
        ["Success", STATUS_COLOR_PALETTE[:success]]
      when :ci_workflow_failed
        ["CI workflow failure", STATUS_COLOR_PALETTE[:failure]]
      when :ci_workflow_unavailable
        ["CI workflow not found", STATUS_COLOR_PALETTE[:failure]]
      when :ci_workflow_halted
        ["CI workflow cancelled", STATUS_COLOR_PALETTE[:inert]]
      when :build_unavailable
        ["Build unavailable", STATUS_COLOR_PALETTE[:failure]]
      when :deployment_failed
        ["Deployment failed", STATUS_COLOR_PALETTE[:failure]]
      else
        ["Unknown", STATUS_COLOR_PALETTE[:neutral]]
      end

    status_badge(status, styles)
  end

  def deployment_run_status_badge(deployment_run)
    status, styles =
      case deployment_run.status.to_sym
      when :created
        ["About to start", STATUS_COLOR_PALETTE[:inert]]
      when :started
        ["Running", STATUS_COLOR_PALETTE[:ongoing]]
      when :submitted
        ["Submitted for review", STATUS_COLOR_PALETTE[:ongoing]]
      when :uploaded
        ["Uploaded", STATUS_COLOR_PALETTE[:routine]]
      when :upload_failed
        ["Upload failed", STATUS_COLOR_PALETTE[:failure]]
      when :rollout_started
        ["In Staged Rollout", STATUS_COLOR_PALETTE[:routine]]
      when :released
        ["Released", STATUS_COLOR_PALETTE[:success]]
      when :failed
        ["Failed", STATUS_COLOR_PALETTE[:failure]]
      else
        ["Unknown", STATUS_COLOR_PALETTE[:neutral]]
      end

    status_badge(status, styles)
  end

  def staged_rollout_status_badge(staged_rollout)
    status, styles =
      case staged_rollout.status.to_sym
      when :started
        ["Rollout active", STATUS_COLOR_PALETTE[:ongoing]]
      when :failed
        ["Rollout failed", STATUS_COLOR_PALETTE[:failure]]
      when :completed
        ["Rollout completed", STATUS_COLOR_PALETTE[:success]]
      when :stopped
        ["Rollout halted", STATUS_COLOR_PALETTE[:inert]]
      else
        ["Unknown", STATUS_COLOR_PALETTE[:neutral]]
      end

    status_badge(status, styles)
  end

  def pull_request_badge(pull_request)
    style =
      case pull_request.state.to_sym
      when :open
        STATUS_COLOR_PALETTE[:success]
      when :closed
        STATUS_COLOR_PALETTE[:ongoing]
      else
        STATUS_COLOR_PALETTE[:neutral]
      end

    status_badge(pull_request.state, style)
  end
end
