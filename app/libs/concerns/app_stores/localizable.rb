module AppStores::Localizable
  ANDROID_LOCALES = YAML.load_file(Rails.root.join("config/locales/android.yml"))["android"] unless const_defined?(:ANDROID_LOCALES)
  IOS_LOCALES = YAML.load_file(Rails.root.join("config/locales/ios.yml"))["ios"] unless const_defined?(:IOS_LOCALES)

  def supported_store_language(locale_tag)
    ANDROID_LOCALES.invert[locale_tag] || IOS_LOCALES.invert[locale_tag]
  end

  def supported_locale_tag?(locale_tag, platform)
    supported_locale_tag(supported_store_language(locale_tag), platform).present?
  end

  def supported_locale_tag(language, platform)
    case platform.to_s
    when "android"
      ANDROID_LOCALES.fetch(language, nil)
    when "ios"
      IOS_LOCALES.fetch(language, nil)
    else
      raise ArgumentError, "Invalid platform"
    end
  end

  module_function :supported_store_language, :supported_locale_tag?, :supported_locale_tag
end
