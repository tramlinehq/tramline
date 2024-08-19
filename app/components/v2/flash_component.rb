class V2::FlashComponent < V2::BaseComponent
  def initialize(flash)
    @flash = flash
  end

  def call
    return if @flash.blank?

    content_tag(:div, class: "mb-3") do
      @flash.select { |_, msg| msg.is_a?(String) }.each do |type, title|
        concat render(V2::AlertComponent.new(type:, title:, dismissible: true))
      end
    end
  end
end
