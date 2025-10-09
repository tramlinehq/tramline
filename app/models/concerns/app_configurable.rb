module AppConfigurable
  INVALID_PLATFORM_ERROR = "platform must be valid"

  # NOTE: not being used by AppVariant, was only being used by GoogleFirebaseIntegration via AppConfig
  # Has been moved into GoogleFirebaseIntegration
  def firebase_app(platform)
    case platform
    when "android" then firebase_android_config["app_id"]
    when "ios" then firebase_ios_config["app_id"]
    else
      raise ArgumentError, INVALID_PLATFORM_ERROR
    end
  end
end
