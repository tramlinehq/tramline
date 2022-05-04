module ApplicationHelper
  def sidebar_active_link(path, style)
    if current_page?(path)
      style
    end
  end
end
