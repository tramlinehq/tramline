class ApplicationController < ActionController::Base
  before_action :require_login, unless: :devise_controller?

  private

  def require_login
    unless current_user
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
end
