class V2::HeaderComponent < V2::BaseComponent
  USER_PROFILE_LINK_CLASSES = "hover:bg-main-100 dark:hover:bg-main-600 dark:text-main-400 dark:hover:text-white"

  def user_email
    current_user.email
  end

  def user_name
    current_user.preferred_name
  end
end
