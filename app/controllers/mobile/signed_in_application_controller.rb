# frozen_string_literal: true

module Mobile
  class SignedInApplicationController < ::SignedInApplicationController
    layout -> { ensure_supported_layout("mobile/signed_in_application") }
    include MobileDeviceAllowable
  end
end
