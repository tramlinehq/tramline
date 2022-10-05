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
      "bg-rose-100"
    else
      "bg-white"
    end
  end

  def version_in_progress(version)
    semver = Semantic::Version.new(version)
    "#{semver.major}.#{semver.minor}.*"
  end

  def text_field_classes(is_disabled:)
    if is_disabled
      "form-input w-full disabled:border-slate-200 disabled:bg-slate-100 disabled:text-slate-600 disabled:cursor-not-allowed"
    else
      "form-input w-full"
    end
  end

  def ago_in_words(time)
    (time.presence && time_ago_in_words(time, include_seconds: true) + " ago") || "N/A"
  end

  def current_deploy
    {
      ref: Site.git_ref,
      ago: ago_in_words(Site.git_ref_at)
    }
  end

  def status_badge(status, style)
    classes = %w[ml-2 text-xs uppercase tracking-wide inline-flex font-medium rounded-full text-center px-2 py-0.5]
    content_tag(:span, status, class: classes.concat(style))
  end

  def link_to_external(name = nil, options = nil, html_options = nil, &block)
    opts = { target: "_blank", rel: "nofollow noopener" }

    if block
      options ||= {}
      options = options.merge(opts)
    else
      html_options ||= {}
      html_options = html_options.merge(opts)
    end

    link_to(name, options, html_options, &block)
  end
end
