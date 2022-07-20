class Authentication::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]
  alias_method :user, :resource
  helper_method :user

  def new
    super do |usr|
      @organization = usr.organizations.build
    end
  end

  def create
    if @token.present?
      build_resource(sign_up_params_for_invites)

      if sign_up_email != @invite.email
        flash.clear
        flash[:notice] = t("invitation.flash.invite_error.email")
        render :new, status: :unprocessable_entity and return
      end

      user.add!(@invite)
    else
      build_resource(sign_up_params)
      user.onboard!
    end

    finish_sign_up
  end

  protected

  def finish_sign_up
    if user.persisted?
      if user.active_for_authentication?
        set_flash_message!(:notice, :signed_up)
        sign_up(resource_name, user)
        respond_with(user, location: after_sign_up_path_for(user))
      else
        set_flash_message!(:notice, :"signed_up_but_#{user.inactive_message}")
        expire_data_after_sign_in!
        respond_with(user, location: after_inactive_sign_up_path_for(user))
      end
    else
      clean_up_passwords(user)
      set_minimum_password_length
      respond_with user
    end
  end

  def set_invite_token
    @token = params[:invite_token]
  end

  def set_invite
    @invite = Accounts::Invite.find_by(token: @token) if @token.present?
  end

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

  def sign_up_params_for_invites
    sign_up_params.except(:organizations_attributes)
  end

  def sign_up_email
    sign_up_params[:email]
  end
end
