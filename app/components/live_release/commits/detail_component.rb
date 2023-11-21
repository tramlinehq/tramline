class LiveRelease::Commits::DetailComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include ReleasesHelper
  include AssetsHelper
  include LinkHelper

  def initialize(commit, number)
    @commit = commit
    @release = commit.release
    @number = number
  end

  attr_reader :commit, :release, :number
  delegate :writer?, to: :helpers
  delegate :stale?, to: :commit

  def number_style
    if stale?
      "bg-slate-100 text-slate-400"
    else
      "bg-slate-200 text-slate-600"
    end
  end

  def link_style
    if stale?
      "text-slate-400"
    else
      "font-medium"
    end
  end

  def commit_link
    link_to_external commit.message.truncate(80), commit.url, class: "underline #{link_style}"
  end

  def commit_number
    "##{number}"
  end

  def commit_info
    formatted_commit_info(commit)
  end

  def apply_commit_button(platform_run)
    form_with(model: commit, url: apply_release_commit_path(release, commit.id), method: :post, builder: ButtonHelper::AuthzForms) do |form|
      concat form.hidden_field :release_platform_run_id, value: platform_run.id
      concat form.authz_submit :blue, "Apply commit to #{platform_run.display_attr(:platform)}"
    end
  end

  def locked_notice
    render "shared/note_box", message: "This release was completed and is now locked."
  end

  def not_triggered?(platform_run)
    commit != platform_run.last_commit && !stale?
  end

  def actionable_commit(run)
    if run.on_track?
      apply_commit_button(run)
    else
      locked_notice
    end
  end

  def platform_runs
    release.release_platform_runs
  end

  def details_toggle
    toggle_for(stale?) do
      content_tag(:span, "Details",
        class: "text-slate-500 font-medium underline mr-2 group-hover:text-slate-800")
    end
  end
end
