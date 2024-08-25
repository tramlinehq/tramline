class V2::FlashComponent < V2::BaseComponent
  def initialize(flash, full_screen: true)
    @flash = flash
    @full_screen = full_screen
  end

  def call
    return if @flash.blank?

    content_tag(:div) do
      @flash.select { |_, msg| msg.is_a?(String) }.each do |type, title|
        concat render(V2::AlertComponent.new(type:, title:, dismissible: true, full_screen: @full_screen))
      end
    end
  end
end
