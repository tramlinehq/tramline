module PasswordHelper
  def password_visibility_toggle_button
    button_styles = "text-gray-500 absolute bottom-0 top-8 right-0 pr-3 flex items-center cursor-pointer"
    visibility_target = {"password-visibility-target": "icon"}

    content_tag(:button, type: "button", data: {action: "password-visibility#toggle"}, tabindex: -1, class: button_styles) do
      icon_visible = content_tag(:span, inline_svg("password_eye.svg", classname: "inline-flex h-6 w-5"), data: visibility_target)
      icon_hidden = content_tag(:span, inline_svg("password_eye_slash.svg", classname: "inline-flex h-6 w-5"), data: visibility_target, class: "hidden")
      icon_visible + icon_hidden
    end
  end
end
