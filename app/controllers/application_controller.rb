class ApplicationController < ActionController::Base
  using RefinedString
  include ExceptionHandler if Rails.env.production? || ENV.fetch("GRACEFUL_ERROR_PAGES", "false").to_boolean
  layout -> { ensure_supported_layout("application") }
  before_action :store_user_location!, if: :storable_location?

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
    around_action :n_plus_one_detection if ENV["N_PLUS_ONE"]

    def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end

  # Its important that the location is NOT stored if:
  # - The request method is not GET (non idempotent)
  # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an
  #    infinite redirect loop.
  # - The request is an Ajax request as this can lead to very unexpected behaviour.
  # - The request is not a Turbo Frame request ([turbo-rails](https://github.com/hotwired/turbo-rails/blob/main/app/controllers/turbo/frames/frame_request.rb))
  def storable_location?
    request.get? &&
      is_navigational_format? &&
      !devise_controller? &&
      !request.xhr? &&
      !turbo_frame_request?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end
end
