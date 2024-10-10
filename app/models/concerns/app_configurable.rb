module AppConfigurable
  include PlatformAwareness

  def firebase_app(platform)
    pick_firebase_app_id(platform)
  end
end
