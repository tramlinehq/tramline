class StatCardComponent < V2::BaseComponent
  renders_one :icon, V2::IconComponent

  def initialize(name, external_url:, external_url_title:)
    raise ArgumentError, "you must provide a url text if external_url is supplied" if external_url.present? && external_url_title.blank?

    @name = name
    @external_url = external_url
    @external_url_title = external_url_title
  end

  attr_reader :name, :external_url, :external_url_title
end
