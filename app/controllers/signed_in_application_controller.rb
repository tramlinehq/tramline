class SignedInApplicationController < ActionController::Base
  layout "signed_in_application"
  before_action :authenticate_user!
  helper_method :current_organization
  helper_method :current_user

  protected

  def current_organization
    @current_organization ||= current_user.organization
  end
end
