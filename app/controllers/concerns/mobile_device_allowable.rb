# frozen_string_literal: true

module MobileDeviceAllowable
  SUPPORTED_MOBILE_DEVICES = %w[smartphone tablet].freeze

  SUPPORTED_MOBILE_DEVICES.each do |device_type|
    define_method(:"#{device_type}_allowed?") do
      true
    end
  end

  def mobile_device?
    device_type.in?(SUPPORTED_MOBILE_DEVICES)
  end
end
