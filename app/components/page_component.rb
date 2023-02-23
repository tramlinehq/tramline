class PageComponent < ViewComponent::Base
  renders_many :actions

  def initialize(title:, breadcrumb: nil)
    @breadcrumb = breadcrumb
    @page_title = title
  end

  attr_reader :breadcrumb, :page_title
end
