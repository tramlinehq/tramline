class ApplicationController < ActionController::Base
  before_action :require_login, unless: :devise_controller?
  helper_method :current_organization

  private

  def require_login
    unless current_user
      flash[:error] = t("errors.messages.not_logged_in")
      redirect_to root_path
    end
  end

  def current_organization
    @current_organization ||= current_user.organization
  end
end
