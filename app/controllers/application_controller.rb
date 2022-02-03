class ApplicationController < ActionController::Base
  include ExceptionHandler

  before_action :require_login, unless: :devise_controller?
  helper_method :current_organization

  DEFAULT_TIMEZONE = "Asia/Kolkata"

  private

  def require_login
    unless current_user
      flash[:error] = t("errors.messages.not_logged_in")
      redirect_to root_path
    end
  end

  def set_time_zone
    tz = @app.present? ? @app.timezone : DEFAULT_TIMEZONE
    Time.use_zone(tz) { yield }
  end

  def current_organization
    @current_organization ||= current_user.organization
  end

  def time_zone
    @current_organization.timezone
  end
end
