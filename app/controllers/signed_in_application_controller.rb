class SignedInApplicationController < ApplicationController
  DEFAULT_TIMEZONE = "Asia/Kolkata"
  before_action :set_paper_trail_whodunnit
  before_action :require_login, unless: :devise_controller?
  helper_method :current_organization
  helper_method :current_user
  helper_method :writer?
  layout -> { ensure_supported_layout("signed_in_application") }

  rescue_from NotAuthorizedError, with: :user_not_authorized

  protected

  def require_login
    unless current_user
      flash[:error] = t("errors.messages.not_logged_in")
      redirect_to root_path
    end
  end

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    referrer = request.referrer == request.url ? root_path : request.referrer
    redirect_to(referrer || root_path)
  end

  def require_write_access!
    raise NotAuthorizedError unless writer?
  end

  def writer?
    current_user.writer_for?(current_organization)
  end

  def set_time_zone
    tz = @app.present? ? @app.timezone : DEFAULT_TIMEZONE
    Time.use_zone(tz) { yield }
  end

  def current_organization
    @current_organization ||=
      if session[:active_organization]
        begin
          Accounts::Organization.friendly.find(session[:active_organization])
        rescue ActiveRecord::RecordNotFound
          current_user.organization
        end
      else
        current_user.organization
      end
  end
end
