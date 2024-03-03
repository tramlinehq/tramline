class V2::BackButtonComponent < V2::BaseComponent
  def initialize(path: nil, to: nil)
    @path = path
    @link_data = (!path) ? history_nav : {}
    @to = to
  end

  def history_nav
    {controller: "navigation", action: "navigation#back"}
  end

  attr_reader :path, :link_data

  def tooltip_text
    return "Go back" unless @to
    "Go back to #{@to}"
  end
end
