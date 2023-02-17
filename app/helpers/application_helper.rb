module ApplicationHelper
  def write_only(&block)
    return concat(content_tag(:div, capture(&block), class: "hidden")) unless writer?
    yield(block)
  end

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

  def step_color(step_kind)
    (step_kind == "release") ? "amber" : "slate"
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

  NOTE_BOX_COLORS = {
    info: "text-amber-500",
    error: "text-red-500"
  }.freeze

  def note_box_color(type)
    NOTE_BOX_COLORS[type]
  end

  def status_badge(status, style, pulse: false)
    classes = %w[text-xs uppercase tracking-wide inline-flex font-medium rounded-full text-center px-2 py-0.5]
    classes << "animate-pulse" if pulse
    content_tag(:span, status, class: classes.concat(style))
  end

  def dev_show(&blk)
    yield blk if Rails.env.development?
  end

  def display_channels(channels)
    channels.map { |chan| [yield(chan), chan.to_json] }
  end

  def time_format(timestamp, with_year: false)
    timestamp.strftime("%b #{timestamp.day.ordinalize}#{", %Y" if with_year} at %-l:%M %P")
  end
end
