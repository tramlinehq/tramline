class Authentication::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, if: :devise_controller?
  alias_method :user, :resource
  helper_method :user

  def new
    super do |usr|
      @organization = usr.organizations.build
    end
  end

  def create
    build_resource(sign_up_params)
    user.onboard!

    if user.persisted?
      if user.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, user)
        respond_with user, location: after_sign_up_path_for(user)
      else
        set_flash_message! :notice, :"signed_up_but_#{user.inactive_message}"
        expire_data_after_sign_in!
        respond_with user, location: after_inactive_sign_up_path_for(user)
      end
    else
      clean_up_passwords user
      set_minimum_password_length
      respond_with user
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(
        :full_name,
        :preferred_name,
        :email,
        :password,
        :password_confirmation,
        organizations_attributes: [:name]
      )
    end
  end
end
