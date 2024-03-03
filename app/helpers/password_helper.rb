module PasswordHelper
  DEFAULT_BUTTON_STYLES = "text-main-500 absolute bottom-0 top-9 right-0 flex items-center cursor-pointer "
  def password_toggle_button(styles: "")
    button_styles = DEFAULT_BUTTON_STYLES + styles
    visibility_target = {"password-visibility-target": "icon"}

    content_tag(:button, type: "button", data: {action: "password-visibility#toggle"}, tabindex: -1, class: button_styles) do
      icon_visible = content_tag(:span, inline_svg("password_eye.svg", classname: "inline-flex h-6 w-5"), data: visibility_target)
      icon_hidden = content_tag(:span, inline_svg("password_eye_slash.svg", classname: "inline-flex h-6 w-5"), data: visibility_target, class: "hidden")
      icon_visible + icon_hidden
    end
  end
end
