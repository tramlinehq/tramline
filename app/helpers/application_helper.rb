module ApplicationHelper
  def sidebar_active_link(path, style)
    if current_page?(path)
      style
    end
  end

  def modal_for(heading, &block)
    render(
      partial: "shared/modal",
      locals: {heading: heading, block: block}
    )
  end
end
