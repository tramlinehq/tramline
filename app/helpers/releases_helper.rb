module ReleasesHelper
  def approval_emoji(status)
    case status
    when "approved"
      "✅"
    when "rejected"
      "❌"
    when "pending"
      "⌛"
    end
  end

  def build_status_badge(status)
    display_data =
      case status
      when Releases::Step::Run.statuses[:on_track]
        ["In Progress", %w[bg-sky-100 text-sky-600]]
      when Releases::Step::Run.statuses[:pending_deployment]
        ["Pending Deployment", %w[bg-indigo-100 text-indigo-600]]
      when Releases::Step::Run.statuses[:success]
        ["Success", %w[bg-green-100 text-green-600]]
      when Releases::Step::Run.statuses[:failed]
        ["Failure", %w[bg-rose-100 text-rose-600]]
      when Releases::Step::Run.statuses[:halted]
        ["Cancelled", %w[bg-yellow-100 text-yellow-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    classes = %w[text-xs uppercase tracking-wide inline-flex font-medium rounded-full text-center px-2 py-0.5]

    content_tag(
      :span,
      display_data.first,
      class: classes.concat(display_data.second)
    )
  end

  def pull_request_badge(state)
    case state
    when "open"
      "bg-green-100 text-green-600"
    when "closed"
      "bg-indigo-100 text-indigo-600"
    else
      "bg-slate-100 text-slate-500"
    end
  end

  def finalize_phase_metadata(release)
    @finalize_phase_metadata ||=
      {
        total_run_time: distance_of_time_in_words(release.created_at, release.completed_at),
        release_tag: release.train.tag_name,
        release_tag_url: release.tag_url,
        final_artifact_url: final_artifact_url(release),
        store_url: release.app.store_link
      }
  end

  def final_artifact_url(release)
    if release.final_artifact_file.present?
      rails_blob_url(release.final_artifact_file, protocol: "https", disposition: "attachment")
    end
  end
end
