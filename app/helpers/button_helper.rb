module ButtonHelper
  BASE_OPTS = "btn group"

  BUTTON_OPTIONS = {
    green: {
      class: "#{BASE_OPTS} bg-emerald-500 enabled:hover:bg-emerald-600 text-white"
    },
    blue: {
      class: "#{BASE_OPTS} bg-indigo-500 enabled:hover:bg-indigo-600 text-white"
    },
    red: {
      class: "#{BASE_OPTS} bg-rose-500 enabled:hover:bg-rose-600 text-white"
    },
    neutral: {
      class: "#{BASE_OPTS} border-slate-300 enabled:border-slate-400 hover:border-slate-400 text-slate-600"
    },
    slate: {
      class: "#{BASE_OPTS} border-slate-400 enabled:border-slate-600 hover:border-slate-600 text-slate-600"
    },
    amber: {
      class: "#{BASE_OPTS} bg-amber-500 enabled:bg-amber-600 hover:bg-amber-600 text-white"
    },
    disabled:
      {
        class: "#{BASE_OPTS} opacity-30 disabled cursor-not-allowed bg-transparent border-slate-300 enabled:hover:border-slate-300",
        disabled: true
      }
  }

  def apply_button_loader(value)
    concat content_tag(:span, value, class: "group-disabled:hidden")
    concat content_tag(:span, "Processing...", class: "hidden group-disabled:inline group-disabled:opacity-60")
  end

  def apply_button_options(options, new_options)
    options ||= {}
    options[:class] ||= ""
    options[:class] << " #{new_options[:class]}"
    options[:class].squish
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

    # if there is no block, the button loader is auto-applied on clicks
    # when block is supplied, the user is expected to attach the button loader inside the block
    if block || style.eql?(:disabled)
      button_to(name, options, html_options, &block)
    else
      button_to(options, html_options) { apply_button_loader(name) }
    end
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

  class AuthzForms < ActionView::Helpers::FormBuilder
    def decorated_submit(style, value, options, &block)
      _options, html_options = @template.apply_button_styles(style, {}, options, nil)

      if block || style.eql?(:disabled)
        button(value, html_options, &block)
      else
        button(html_options) { @template.apply_button_loader(value) }
      end
    end

    def authz_submit(style, value = nil, options = nil, &block)
      style = :disabled unless @template.writer?
      decorated_submit(style, value, options, &block)
    end
  end
end
