ANDROID_LOCALES = YAML.load_file(Rails.root.join("config/locales/android.yml"))["android"]
IOS_LOCALES = YAML.load_file(Rails.root.join("config/locales/ios.yml"))["ios"]
SUPPORTED_LANGUAGES = ANDROID_LOCALES.keys & IOS_LOCALES.keys

module AppStores::Localizable
  def supported_locale_language?(language)
    SUPPORTED_LANGUAGES.include?(language)
  end

  def supported_store_language(locale_tag)
    ANDROID_LOCALES.invert[locale_tag] || IOS_LOCALES.invert[locale_tag]
  end

  def supported_locale_tag?(locale_tag)
    supported_locale_language?(supported_store_language(locale_tag))
  end

  def supported_locale_tag(language, platform)
    return unless supported_locale_language?(language)

    case platform.to_s
    when "android"
      ANDROID_LOCALES[language]
    when "ios"
      IOS_LOCALES[language]
    else
      nil
    end
  end

  module_function :supported_store_language, :supported_locale_language?, :supported_locale_tag?, :supported_locale_tag
end
