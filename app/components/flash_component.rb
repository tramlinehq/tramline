class FlashComponent < BaseComponent
  def initialize(flash, full_screen: true)
    @flash = flash
    @full_screen = full_screen
  end

  def call
    return if @flash.blank?

    content_tag(:div) do
      @flash.each do |type, messages|
        render_type, html_safe = parse_flash_type(type)
        Array(messages).compact_blank.each do |message|
          message = message.html_safe if html_safe # rubocop:disable Rails/OutputSafety -- trusted server-generated flash content
          concat render(AlertComponent.new(type: render_type, title: message, dismissible: true, full_screen: @full_screen))
        end
      end
    end
  end

  private

  def parse_flash_type(type)
    type = type.to_s
    if type.end_with?("_html")
      [type.delete_suffix("_html"), true]
    else
      [type, false]
    end
  end
end
