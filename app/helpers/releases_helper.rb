module ReleasesHelper
  include Memery

  def approval_emoji(step_run)
    case step_run.approval_status.to_sym
    when :approved
      "✅"
    when :rejected
      "❌"
    when :pending
      "⌛"
    else
      "❔"
    end
  end

  def build_status_badge(step_run)
    display_data =
      case step_run.status.to_sym
      when :ci_workflow_triggered, :on_track
        ["Waiting for CI", %w[bg-sky-100 text-sky-600]]
      when :ci_workflow_started
        ["In Progress", %w[bg-sky-100 text-sky-600]]
      when :build_ready, :deployment_started
        ["Deployments Pending", %w[bg-indigo-100 text-indigo-600]]
      when :success
        ["Success", %w[bg-green-100 text-green-600]]
      when :ci_workflow_failed
        ["CI Workflow Failure", %w[bg-rose-100 text-rose-600]]
      when :ci_workflow_unavailable
        ["CI Workflow Not Found", %w[bg-rose-100 text-rose-600]]
      when :ci_workflow_halted
        ["CI Workflow Cancelled", %w[bg-yellow-100 text-yellow-600]]
      when :build_unavailable
        ["Build Unavailable", %w[bg-rose-100 text-rose-600]]
      when :deployment_failed
        ["Deployment Failed", %w[bg-rose-100 text-rose-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    status_badge(display_data.first, display_data.second)
  end

  def deployment_run_status_badge(deployment_run)
    display_data =
      case deployment_run.status.to_sym
      when :created
        ["About To Start", %w[bg-amber-100 text-amber-600]]
      when :started
        ["Running", %w[bg-indigo-100 text-indigo-600]]
      when :uploaded
        ["Uploaded", %w[bg-slate-100 text-slate-500]]
      when :upload_failed
        ["Upload Failed", %w[bg-rose-100 text-rose-600]]
      when :released
        ["Released", %w[bg-green-100 text-green-600]]
      when :failed
        ["Failed", %w[bg-rose-100 text-rose-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    status_badge(display_data.first, display_data.second)
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

  # TODO: deprecate this method, it's redundant
  memoize def finalize_phase_metadata(release)
    release.finalize_phase_metadata
  end
end
