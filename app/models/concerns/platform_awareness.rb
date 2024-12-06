module PlatformAwareness
  ERROR_MESSAGE = "platform must be valid"
  def pick_firebase_app_id(platform)
    case platform
    when "android" then firebase_android_config["app_id"]
    when "ios" then firebase_ios_config["app_id"]
    else
      raise ArgumentError, ERROR_MESSAGE
    end
  end

  def pick_bugsnag_release_stage(platform)
    case platform
    when "android" then bugsnag_android_config["release_stage"]
    when "ios" then bugsnag_ios_config["release_stage"]
    else
      raise ArgumentError, ERROR_MESSAGE
    end
  end

  def pick_bugsnag_project_id(platform)
    case platform
    when "android" then bugsnag_android_config["project_id"]
    when "ios" then bugsnag_ios_config["project_id"]
    else
      raise ArgumentError, ERROR_MESSAGE
    end
  end

  def pick_firebase_crashlytics_app_id(platform)
    case platform
    when "android" then firebase_crashlytics_android_config["app_id"]
    when "ios" then firebase_crashlytics_ios_config["app_id"]
    else
      raise ArgumentError, ERROR_MESSAGE
    end
  end
end
