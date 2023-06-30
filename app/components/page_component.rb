class PageComponent < ViewComponent::Base
  renders_many :actions
  include AssetsHelper

  def initialize(title:, breadcrumb: nil, subtitle: nil)
    @breadcrumb = breadcrumb
    @page_title = title
    @subtitle = subtitle
  end

  attr_reader :breadcrumb, :page_title, :subtitle
end
