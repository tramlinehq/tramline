module ClipboardHelper
  DEFAULT_BUTTON_STYLES = "text-main-500 absolute bottom-0 top-7 right-0 flex items-center cursor-pointer "
  def copy_to_clipboard_button(target, styles: "")
    content_tag(:button,
      type: "button",
      data: {action: "clipboard#copy", clipboard_target: target},
      tabindex: "-1",
      class: DEFAULT_BUTTON_STYLES + styles) do
      inline_svg("clipboard_copy.svg", classname: "inline-flex w-5")
    end
  end
end
