class PageComponent < ViewComponent::Base
  renders_many :actions

  def initialize(breadcrumb:, title:)
    @breadcrumb = breadcrumb
    @page_title = title
  end

  attr_reader :breadcrumb, :page_title
end
