module ButtonHelper
  BUTTON_STYLES = {
    green: "bg-emerald-500 hover:bg-emerald-600 text-white",
    red: "",
    neutral: "text-slate-600 border-slate-300 hover:border-slate-400",
    disabled: "opacity-30 cursor-not-allowed border-slate-300 hover:border-slate-300"
  }

  def button_link_to(style, name = nil, options = nil, html_options = nil, &block)
    styles = " btn " + BUTTON_STYLES[style]

    if block
      options ||= {class: ""}
      options[:class] << styles
    else
      html_options ||= {class: ""}
      html_options[:class] << styles
    end

    link_to(name, options, html_options, &block)
  end

  def authz_link_to(style, name = nil, options = nil, html_options = nil, &block)
    unless writer?
      style = :disabled
    end

    if block
      unless writer?
        name = "javascript:void(0);"
      end
    else
      unless writer?
        options = "javascript:void(0);"
      end
    end

    button_link_to(style, name, options, html_options, &block)
  end

  def link_to_external(name = nil, options = nil, html_options = nil, &block)
    opts = {target: "_blank", rel: "nofollow noopener"}

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
