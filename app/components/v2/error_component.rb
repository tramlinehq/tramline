class V2::ErrorComponent < V2::BaseComponent
  def initialize(resource, full_screen: true)
    @errors = resource&.errors
    @full_screen = full_screen
  end

  def call
    return if @errors.blank?

    content_tag(:div, class: "flex flex-col gap-2") do
      @errors.collect do |error|
        concat render(V2::AlertComponent.new(type: :error, title: simple_format(error.full_message, sanitize: true), dismissible: true, full_screen: @full_screen))
      end
    end
  end
end
