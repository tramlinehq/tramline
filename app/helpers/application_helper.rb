module ApplicationHelper
  def sidebar_active_path(path, style)
    if current_page?(path)
      style
    end
  end

  def sidebar_active_resource(resource, style)
    if resource.eql?(controller_name)
      style
    end
  end

  def modal_for(heading, &block)
    render(
      partial: "shared/modal",
      locals: {
        heading: heading, block: block
      }
    )
  end

  def dynamic_header_color
    if Rails.env.development?
      "bg-amber-400"
    else
      "bg-white"
    end
  end

  def version_in_progress(version)
    semver = Semantic::Version.new(version)
    "#{semver.major}.#{semver.minor}.*"
  end

  def disabled_text_field_classes(disabled)
    if disabled
      "form-input w-full disabled:border-slate-200 disabled:bg-slate-100 disabled:text-slate-600 disabled:cursor-not-allowed"
    else
      "form-input w-full"
    end
  end
end
