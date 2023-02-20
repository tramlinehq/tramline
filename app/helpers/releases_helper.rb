module ReleasesHelper
  include Memery

  SHOW_RELEASE_STATUS = {
    finished: ["Completed", %w[bg-green-100 text-green-600]],
    stopped: ["Stopped", %w[bg-amber-100 text-amber-600]],
    on_track: ["Running", %w[bg-blue-100 text-blue-600]],
    post_release: ["Finalizing", %w[bg-slate-100 text-slate-500]],
    post_release_started: ["Finalizing", %w[bg-slate-100 text-slate-500]],
    post_release_failed: ["Finalizing", %w[bg-slate-100 text-slate-500]]
  }

  def release_status_badge(status)
    status, styles = SHOW_RELEASE_STATUS.fetch(status.to_sym)
    status_badge(status, styles)
  end

  def build_status_badge(step_run)
    status, styles =
      case step_run.status.to_sym
      when :ci_workflow_triggered, :on_track
        ["Waiting for CI", %w[bg-sky-100 text-sky-600]]
      when :ci_workflow_started
        ["In progress", %w[bg-sky-100 text-sky-600]]
      when :build_ready
        ["Looking for build to deploy", %w[bg-indigo-100 text-indigo-600]]
      when :deployment_started
        ["Deployments in progress", %w[bg-indigo-100 text-indigo-600]]
      when :build_found_in_store
        ["Build found in store", %w[bg-cyan-100 text-cyan-600]]
      when :build_not_found_in_store
        ["Build not found in store", %w[bg-rose-100 text-rose-600]]
      when :success
        ["Success", %w[bg-green-100 text-green-600]]
      when :ci_workflow_failed
        ["CI workflow failure", %w[bg-rose-100 text-rose-600]]
      when :ci_workflow_unavailable
        ["CI workflow not found", %w[bg-rose-100 text-rose-600]]
      when :ci_workflow_halted
        ["CI workflow cancelled", %w[bg-yellow-100 text-yellow-600]]
      when :build_unavailable
        ["Build unavailable", %w[bg-rose-100 text-rose-600]]
      when :deployment_failed
        ["Deployment failed", %w[bg-rose-100 text-rose-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    status_badge(status, styles)
  end

  def deployment_run_status_badge(deployment_run)
    status, styles =
      case deployment_run.status.to_sym
      when :created
        ["About to start", %w[bg-amber-100 text-amber-600]]
      when :started
        ["Running", %w[bg-indigo-100 text-indigo-600]]
      when :submitted
        ["Submitted for review", %w[bg-indigo-100 text-indigo-600]]
      when :uploaded
        ["Uploaded", %w[bg-slate-100 text-slate-500]]
      when :upload_failed
        ["Upload failed", %w[bg-rose-100 text-rose-600]]
      when :rollout_started
        ["In Staged Rollout", %w[bg-indigo-100 text-indigo-600]]
      when :released
        ["Released", %w[bg-green-100 text-green-600]]
      when :failed
        ["Failed", %w[bg-rose-100 text-rose-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    status_badge(status, styles)
  end

  def staged_rollout_status_badge(staged_rollout)
    status, styles =
      case staged_rollout.status.to_sym
      when :started
        ["Rollout active", %w[bg-indigo-100 text-indigo-600]]
      when :failed
        ["Rollout failed", %w[bg-rose-100 text-rose-600]]
      when :completed
        ["Rollout completed", %w[bg-green-100 text-green-600]]
      when :stopped
        ["Rollout halted", %w[bg-amber-100 text-amber-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    status_badge(status, styles)
  end

  def pull_request_badge(pull_request)
    case pull_request.state.to_sym
    when :open
      "bg-green-100 text-green-600"
    when :closed
      "bg-indigo-100 text-indigo-600"
    else
      "bg-slate-100 text-slate-500"
    end
  end
end
