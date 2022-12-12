module ButtonHelper
  BUTTON_OPTIONS = {
    green: {
      class: "btn bg-emerald-500 hover:bg-emerald-600 text-white"
    },
    blue: {
      class: "btn bg-indigo-500 hover:bg-indigo-600 text-white"
    },
    red: {
      class: "btn bg-rose-500 hover:bg-rose-600 text-white"
    },
    neutral: {
      class: "btn text-slate-600 border-slate-300 hover:border-slate-400"
    },
    disabled:
      {
        class: "btn opacity-30 disabled cursor-not-allowed bg-transparent border-slate-300 hover:border-slate-300",
        disabled: true
      }
  }

  def apply_button_options(options, new_options)
    options ||= {}
    options[:class] ||= ""
    options[:class] << " #{new_options[:class]}"
    options.merge(new_options.except(:class))
  end

  def apply_button_styles(style, options, html_options, block)
    new_opts = BUTTON_OPTIONS[style]

    if block
      options = apply_button_options(options, new_opts)
    else
      html_options = apply_button_options(html_options, new_opts)
    end

    [options, html_options]
  end

  # link that looks like a styled button
  def decorated_link_to(style, name = nil, options = nil, html_options = nil, &block)
    options, html_options = apply_button_styles(style, options, html_options, block)
    link_to(name, options, html_options, &block)
  end

  # styled button with path
  def decorated_button_to(style, name = nil, options = nil, html_options = nil, &block)
    options, html_options = apply_button_styles(style, options, html_options, block)
    button_to(name, options, html_options, &block)
  end

  # styled button tag
  def decorated_button_tag(style, options = nil, html_options = nil, &block)
    options, html_options = apply_button_styles(style, options, html_options, block)
    button_tag(options, html_options, &block)
  end

  # auth-aware link that looks like a styled button
  def authz_link_to(style, name = nil, options = nil, html_options = nil, &block)
    style = :disabled unless writer?

    if block
      unless writer?
        name = "javascript:void(0);"
      end
    else
      unless writer?
        options = "javascript:void(0);"
      end
    end

    decorated_link_to(style, name, options, html_options, &block)
  end

  # auth-aware styled button with path
  def authz_button_to(style, name = nil, options = nil, html_options = nil, &block)
    style = :disabled unless writer?
    decorated_button_to(style, name, options, html_options, &block)
  end

  # open a link in a new tab
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

  class AuthzForms < ActionView::Helpers::FormBuilder
    def authz_submit(style, value = nil, options = nil)
      style = :disabled unless @template.writer?
      _options, html_options = @template.apply_button_styles(style, {}, options, nil)
      submit(value, html_options)
    end
  end
end
