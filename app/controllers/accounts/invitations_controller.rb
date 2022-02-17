class Accounts::InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters, if: :devise_controller?
  alias_method :user, :resource
  helper_method :user

  layout "signed_in_application", only: [:new]

  def new
    super
  end

  def create
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [:full_name, :preferred_name, :email, :role])
  end
end
