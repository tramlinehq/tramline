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
end
