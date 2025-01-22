class FlashComponent < BaseComponent
  def initialize(flash, full_screen: true)
    @flash = flash
    @full_screen = full_screen
  end

  def call
    return if @flash.blank?

    content_tag(:div) do
      @flash.each do |type, messages|
        Array(messages).compact_blank.each do |message|
          concat render(AlertComponent.new(type:, title: message, dismissible: true, full_screen: @full_screen))
        end
      end
    end
  end
end
