module ApplicationHelper
  def sidebar_active_link(path, style)
    style if current_page?(path)
  end

  def modal_for(heading, &block)
    render(
      partial: "shared/modal",
      locals: { heading: heading, block: block }
    )
  end
end
