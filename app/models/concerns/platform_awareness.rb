module PlatformAwareness
  def pick_firebase_app_id(platform)
    case platform
    when "android" then firebase_android_config["app_id"]
    when "ios" then firebase_ios_config["app_id"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end

  def pick_bugsnag_release_stage(platform)
    case platform
    when "android" then bugsnag_android_config["release_stage"]
    when "ios" then bugsnag_ios_config["release_stage"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end

  def pick_bugsnag_project_id(platform)
    case platform
    when "android" then bugsnag_android_config["project_id"]
    when "ios" then bugsnag_ios_config["project_id"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end
end
