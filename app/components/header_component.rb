class HeaderComponent < BaseComponent
  USER_PROFILE_LINK_CLASSES = "hover:bg-main-100 dark:hover:bg-main-600 dark:text-secondary-50 dark:hover:text-white"
  renders_one :sticky_message

  def user_email
    current_user.email
  end

  def user_name
    current_user.preferred_name || user_full_name
  end

  def user_full_name
    current_user.full_name
  end

  def app_icon
    default_app.icon.attached? ? rails_blob_path(default_app.icon) : "art/cross_platform_default.png"
  end
end
