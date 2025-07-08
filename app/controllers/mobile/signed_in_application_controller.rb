# frozen_string_literal: true

module Mobile
  class SignedInApplicationController < ::SignedInApplicationController
    layout -> { ensure_supported_layout("mobile/signed_in_application") }
    include MobileDeviceAllowable
    helper_method :default_mobile_alert

    def default_mobile_alert
      "Tramline is best used on desktop browsers. This is a limited mobile experience that lists the current releases across all your apps and allows you to control active production rollouts."
    end
  end
end
