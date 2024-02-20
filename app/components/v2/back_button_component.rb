class V2::BackButtonComponent < ViewComponent::Base
  def initialize(path = nil)
    @path = path
    @link_data = (!path) ? history_nav : {}
  end

  def history_nav
    {controller: "navigation", action: "navigation#back"}
  end

  attr_reader :path, :link_data
end
