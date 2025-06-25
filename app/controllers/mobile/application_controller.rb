# frozen_string_literal: true

module Mobile
  class ApplicationController < ::ApplicationController
    layout -> { ensure_supported_layout("mobile_application") }
    include MobileDeviceAllowable
  end
end
