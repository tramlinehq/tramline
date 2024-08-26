class V2::FlashComponent < V2::BaseComponent
  def initialize(flash, full_screen: true)
    @flash = flash
    @full_screen = full_screen
  end

  def call
    return if @flash.blank?

    content_tag(:div) do
      @flash.each do |type, messages|
        Array(messages).compact.each do |message|
          concat render(V2::AlertComponent.new(type:, title: message, dismissible: true, full_screen: @full_screen))
        end
      end
    end
  end
end
