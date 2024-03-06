module PlatformAwareness
  def platform_aware_config(ios, android)
    if app.android?
      {android: android}
    elsif app.ios?
      {ios: ios}
    elsif app.cross_platform?
      {ios: ios, android: android}
    end
  end

  def pick_firebase_app_id(platform)
    case platform
    when "android"
      firebase_android_config["app_id"]
    when "ios"
      firebase_ios_config["app_id"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end

  def pick_bugsnag_release_stage(platform)
    case platform
    when "android"
      bugsnag_android_config["release_stage"]
    when "ios"
      bugsnag_ios_config["release_stage"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end

  def pick_bugsnag_project_id(platform)
    case platform
    when "android"
      bugsnag_android_config["project_id"]
    when "ios"
      bugsnag_ios_config["project_id"]
    else
      raise ArgumentError, "platform must be valid"
    end
  end
end
