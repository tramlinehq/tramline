class V2::HeaderComponent < V2::BaseComponent
  USER_PROFILE_LINK_CLASSES = "hover:bg-main-100 dark:hover:bg-main-600 dark:text-main-400 dark:hover:text-white"
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

  def app_icon(app)
    return app.latest_external_apps[:android].icon.blob.url if app.latest_external_apps[:android].icon.attached?
    "art/cross_platform_default.png"
  end
end
