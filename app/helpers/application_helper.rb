module ApplicationHelper
  using RefinedString

  NOT_AVAILABLE = "⃠"

  STATUS_COLOR_PALETTE = {
    success: %w[bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300],
    failure: %w[bg-rose-100 text-rose-800 dark:bg-red-900 dark:text-red-300],
    routine: %w[bg-sky-100 text-sky-600],
    neutral: %w[bg-slate-100 text-slate-500],
    ongoing: %w[bg-indigo-100 text-indigo-600],
    inert: %w[bg-amber-100 text-amber-800]
  }

  STATUS_BORDER_COLOR_PALETTE = {
    success: "border-green-700",
    failure: "border-red-700",
    neutral: "border-slate-200"
  }

  PILL_STATUS_COLOR_PALETTE = {
    success: %w[bg-green-500],
    failure: %w[bg-red-500],
    routine: %w[bg-sky-500],
    ongoing: %w[bg-indigo-500],
    inert: %w[bg-amber-500],
    neutral: %w[bg-slate-500]
  }

  PROGRESS_BAR_COLOR_PALETTE = {
    default: "bg-blue-600 dark:bg-blue-500",
    inert: "bg-main-400 dark:bg-main-200"
  }

  def setup_instruction_color(is_completed)
    is_completed ? "bg-green-400" : "bg-blue-200"
  end

  def status_picker(picker, status)
    picker[status.to_sym] || {text: status.humanize, status: :neutral}
  end

  def resolve_color(color)
    if color.to_sym.in?(%i[excellent acceptable mediocre])
      "var(--color-reldex-#{color})"
    else
      color
    end
  end

  def toggle_for(hide, full_width: false, &block)
    render(
      partial: "shared/toggle_button",
      locals: {
        hide: hide, block: block, full_width: full_width
      }
    )
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

  def ago_in_words(time, prefix: nil, suffix: "ago")
    return "N/A" unless time
    builder = ""
    builder += "#{prefix} " if prefix
    builder += time_ago_in_words(time, include_seconds: true)
    builder += " #{suffix}" if suffix
    builder
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

  def status_badge(status, custom = [], fixed = nil, pulse: false)
    return if status.blank?

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

  def display_channels(channels, with_none: false)
    channels
      .map { |chan| [yield(chan), chan.to_json] }
      .tap { |list| with_none ? list.unshift(["None", nil]) : nil }
  end

  def time_format(timestamp, with_year: false, with_time: true, only_time: false, only_date: false, dash_empty: false, only_day: false)
    return "--" if dash_empty && timestamp.nil?
    return unless timestamp
    return timestamp.strftime("%-l:%M %P") if only_time
    return timestamp.strftime("#{timestamp.day.ordinalize} %b") if only_day
    return timestamp.strftime("%A #{timestamp.day.ordinalize} %B, %Y") if only_date
    timestamp.strftime("%b #{timestamp.day.ordinalize}#{", %Y" if with_year}#{" at %-l:%M %P" if with_time}")
  end

  def subtitle(text)
    content_tag(:span, text, class: "text-sm text-slate-400")
  end

  def short_sha(sha)
    sha[0, 7]
  end

  def user_avatar(name, **)
    Initials.svg(name, **)
  end

  def comment
  end

  def duration_in_words(seconds)
    return NOT_AVAILABLE unless seconds
    distance_of_time_in_words(0, seconds, include_seconds: true)
  end

  def page_title(page_name, current_organization, app, release)
    suffix = I18n.t("page_titles.default_suffix", default: "Tramline")
    middle_section = app&.name || current_organization&.name
    prefix = if release&.original_release_version.present?
      release.original_release_version
    else
      page_name || middle_section
    end

    [prefix.titleize, middle_section.titleize, suffix.titleize].compact.join(" | ")
  end
end
