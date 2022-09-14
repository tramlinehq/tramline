class AdminApplicationController < ApplicationController
  before_action :set_paper_trail_whodunnit

  layout "admin_application"

  before_action :require_login, unless: :devise_controller?
  helper_method :current_user

  DEFAULT_TIMEZONE = "Asia/Kolkata"

  protected

  def require_login
    unless current_user&.admin?
      flash[:error] = t("errors.messages.not_logged_in")
      redirect_to root_path
    end
  end

  def set_time_zone
    tz = @app.present? ? @app.timezone : DEFAULT_TIMEZONE
    Time.use_zone(tz) { yield }
  end
end
