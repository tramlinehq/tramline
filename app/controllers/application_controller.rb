class ApplicationController < ActionController::Base
  using RefinedString
  include ExceptionHandler if Rails.env.production? || ENV.fetch("GRACEFUL_ERROR_PAGES", "false").to_boolean
  layout -> { ensure_supported_layout("application") }

  class NotAuthorizedError < StandardError; end

  def raise_not_found
    raise ActionController::RoutingError, "Unknown url: #{params[:unmatched_route]}"
  end

  protected

  def ensure_supported_layout(layout)
    if supported_device?
      layout
    else
      "unsupported_device"
    end
  end

  def supported_device?
    device_type.in?(%w[desktop])
  end

  def device_type
    DeviceDetector.new(request.user_agent).device_type
  end

  unless Rails.env.production?
    around_action :n_plus_one_detection

    def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end
end
