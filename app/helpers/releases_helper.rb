module ReleasesHelper
  include ApplicationHelper
  include Memery

  SHOW_RELEASE_STATUS = {
    finished: ["Completed", :success],
    stopped: ["Stopped", :inert],
    created: ["Running", :ongoing],
    on_track: ["Running", :ongoing],
    post_release: ["Finalizing", :neutral],
    post_release_started: ["Finalizing", :neutral],
    post_release_failed: ["Finalizing", :neutral],
    partially_finished: ["Partially Finished", :ongoing],
    stopped_after_partial_finish: ["Stopped & Partially Finished", :inert]
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
      when :deployment_started, :deployment_restarted
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
      when :failed_with_action_required
        ["Needs manual submission", :failure]
      when :cancelling
        ["Cancelling", :inert]
      when :cancelled
        ["Cancelled", :inert]
      when :cancelled_before_start
        ["Overwritten", :neutral]
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
      when :preparing_release
        ["Preparing store version", :ongoing]
      when :prepared_release
        ["Ready for review", :ongoing]
      when :failed_prepare_release
        ["Failed to start release", :inert]
      when :submitted_for_review
        ["Submitted for review", :ongoing]
      when :review_failed
        ["Review rejected", :failure]
      when :ready_to_release
        ["Review approved", :ongoing]
      when :uploading
        ["Uploading", :routine]
      when :uploaded
        ["Uploaded", :routine]
      when :rollout_started
        ["Release in progress", :routine]
      when :released
        ["Released", :success]
      when :failed
        ["Failed", :failure]
      when :failed_with_action_required
        ["Needs manual submission", :failure]
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

  def stop_release_warning(release)
    message = ""
    message += "You have finished release to one of the platforms. " if release.partially_finished?
    message += "You have unmerged commits in this release branch. " if release.all_commits.size > 1
    message + "Are you sure you want to stop the release?"
  end

  def formatted_commit_info(commit)
    name = commit.author_name || commit.author_login
    author_link = commit.author_url || "mailto:#{commit.author_email}"
    author_url = link_to_external(name, author_link, class: "underline")
    builder = content_tag(:code, commit.short_sha)
    builder += " • "
    builder += author_url + " committed " + ago_in_words(commit.timestamp)
    builder += " • applied " + ago_in_words(commit.applied_at) if commit.applied_at.present?
    builder
  end

  def blocked_step_release_link(release)
    release_url = if release.ongoing?
      hotfix_release_app_train_releases_path(release.train.app, release.train)
    else
      ongoing_release_app_train_releases_path(release.train.app, release.train)
    end
    link_text = release.ongoing? ? "current hotfix release" : "current ongoing release"
    link_to link_text, release_url, class: "underline"
  end

  def release_title(release)
    if release.hotfix?
      concat content_tag :span, release.release_version.to_s, class: "pr-2"
      concat inline_svg("band_aid.svg", classname: "w-6 align-middle inline-flex")
      content_tag :span, "hotfix release", class: "ml-2 text-sm bg-amber-50 px-2 py-1"
    else
      release.release_version
    end
  end

  def hotfixed_from(release)
    hotfixed_from = release.hotfixed_from
    content_tag(:div, class: "inline-flex") do
      concat content_tag(:span, "(hotfixed from&nbsp;".html_safe)
      concat link_to content_tag(:code, hotfixed_from.release_version.to_s), hotfixed_from.live_release_link, class: "underline"
      concat content_tag(:span, ")")
    end
  end
end
