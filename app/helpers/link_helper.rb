module LinkHelper
  # open link in a new tab
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

  def _link_to(external, options, html_options, &)
    return link_to_external(options, html_options, &) if external
    link_to(options, html_options, &)
  end
end
