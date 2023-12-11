# frozen_string_literal: true

class V2::HeaderComponent < V2::BaseComponent
  USER_PROFILE_LINK_CLASSES = "hover:bg-gray-100 dark:hover:bg-gray-600 dark:text-gray-400 dark:hover:text-white"

  def user_email
    current_user.email
  end

  def user_name
    current_user.preferred_name
  end
end
