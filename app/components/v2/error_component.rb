class V2::ErrorComponent < V2::BaseComponent
  def initialize(resource)
    @errors = resource&.errors
  end

  def call
    return if @errors.blank?

    content_tag(:div) do
      @errors.collect do |error|
        concat render(V2::AlertComponent.new(type: :error, title: simple_format(error.full_message, sanitize: true), dismissible: true))
      end
    end
  end
end
