module ApplicationHelper
  using RefinedString

  STATUS_COLOR_PALETTE = {
    success: %w[bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300],
    failure: %w[bg-rose-100 text-rose-800 dark:bg-red-900 dark:text-red-300],
    routine: %w[bg-sky-100 text-sky-600],
    neutral: %w[bg-slate-100 text-slate-500],
    ongoing: %w[bg-indigo-100 text-indigo-600],
    inert: %w[bg-amber-100 text-amber-600]
  }

  PILL_STATUS_COLOR_PALETTE = {
    success: %w[bg-green-500],
    failure: %w[bg-red-500],
    ongoing: %w[bg-indigo-500],
    inert: %w[bg-amber-500]
  }

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

  def toggle_for(hide, &block)
    render(
      partial: "shared/toggle_button",
      locals: {
        hide: hide, block: block
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
    version.to_semverish.to_s(patch_glob: true)
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

  def time_in_words(time)
    (time.presence && time_ago_in_words(time, include_seconds: true)) || "N/A"
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

  def status_badge(status, custom = [], fixed = nil, pulse: false)
    styles =
      case custom
      when Array
        if fixed.nil?
          custom
        else
          custom.concat(STATUS_COLOR_PALETTE[fixed])
        end
      when Symbol
        STATUS_COLOR_PALETTE[custom]
      else
        STATUS_COLOR_PALETTE[fixed] unless fixed.nil?
      end

    classes = %w[text-xs uppercase tracking-wide inline-flex font-medium rounded-full text-center px-2 py-0.5]
    classes << "animate-pulse" if pulse
    classes.concat(styles) if styles
    content_tag(:span, status, class: classes)
  end

  def dev_show(&blk)
    yield blk if Rails.env.development?
  end

  def display_channels(channels, with_none: false)
    channels
      .map { |chan| [yield(chan), chan.to_json] }
      .tap { |list| with_none ? list.unshift(["None", nil]) : nil }
  end

  def time_format(timestamp, with_year: false, with_time: true, only_time: false, only_date: false, dash_empty: false)
    return "-" if dash_empty && timestamp.nil?
    return unless timestamp
    return timestamp.strftime("%-l:%M %P") if only_time
    return timestamp.strftime("%A #{timestamp.day.ordinalize} %B, %Y") if only_date
    timestamp.strftime("%b #{timestamp.day.ordinalize}#{", %Y" if with_year}#{" at %-l:%M %P" if with_time}")
  end

  def subtitle(text)
    content_tag(:span, text, class: "text-sm text-slate-400")
  end

  def short_sha(sha)
    sha[0, 7]
  end

  def user_avatar(name, **options)
    Initials.svg(name, **options)
  end

  def safe_simple_format(text)
    simple_format(h(text))
  end
end
