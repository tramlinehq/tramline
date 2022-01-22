module ApplicationHelper
  def developer_commentary
    return unless Flipper.enabled?(:developer_commentary)

    content_tag(:dev, class: "developer-commentary") do
      concat(content_tag(:strong, "Developer Commentary"))
      yield
    end
  end
end
