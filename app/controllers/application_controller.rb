class ApplicationController < ActionController::Base
  using RefinedString
  include Exceptionable if Rails.env.production? || ENV.fetch("GRACEFUL_ERROR_PAGES", "false").to_boolean
  layout -> { ensure_supported_layout("application") }
  before_action :store_user_location!, if: :storable_location?
  helper_method :writer?

  class NotAuthorizedError < StandardError; end

  def raise_not_found
    raise ActionController::RoutingError, "Unknown url: #{params[:unmatched_route]}"
  end

  def writer?
    false
  end

  def device
    @device ||= DeviceDetector.new(request.user_agent)
  end

  def authenticated_root_path
    apps_path
  end

  def current_organization
    @current_organization ||=
      if session[:active_organization]
        begin
          Accounts::Organization.friendly.find(session[:active_organization])
        rescue ActiveRecord::RecordNotFound
          current_user&.organizations&.first
        end
      else
        current_user&.organizations&.first
      end
  end

  def current_user
    @current_user ||= current_email_authentication&.user || @current_sso_user
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
    device.device_type
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
  # - The request method is not GET (non idempotent).
  # - The request is from Devise::SessionsController, could cause an infinite redirect loop.
  # - The request is an Ajax request as this can lead to very unexpected behaviour.
  # - The request is not a Turbo Frame request.
  def storable_location?
    request.get? &&
      is_navigational_format? &&
      !authentication_controllers? &&
      !request.xhr? &&
      !turbo_frame_request?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  def after_sign_in_path_for(_)
    return authenticated_admin_root_path if current_user&.admin?

    stored_location = stored_location_for(:user)
    if stored_location&.include? new_authentication_invite_confirmation_path
      return authenticated_root_path
    end

    stored_location || authenticated_root_path
  end

  def authentication_controllers?
    devise_controller? || controller_name == "sessions"
  end
end
