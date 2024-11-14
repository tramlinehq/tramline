module Installations
  class Crashlytics::Error
    ERROR_CODES = {
      "INVALID_LOGIN_CREDENTIALS" => "The credentials provided are invalid.",
      "WEAK_PASSWORD : Password should be at least 6 characters" => "Password should be at least 6 characters for new Firebase user",
      "API key not valid. Please pass a valid API key." => "API key not valid. Please pass a valid API key."
    }

    def self.set_error_message(message)
      I18n.backend.store_translations(:en, {
        activerecord: {
          errors: {
            crashlytics_integration: {
              attributes: {
                installation_error: ERROR_CODES[message]
              }
            }
          }
        }
      })
    end

    def self.get_error_message
      I18n.t("activerecord.errors.crashlytics_integration.attributes.installation_error")
    end
  end
end
