class Authentication::RegistrationsController < Devise::RegistrationsController
  include ExceptionHandler

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]
  alias_method :user, :resource
  helper_method :user

  def new
    if @token.present?
      flash[:notice] = t("invitation.flash.signup_before", org: @invite.organization.name)
    end

    super do |usr|
      @organization = usr.organizations.build
      @user.email = @invite&.email
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
      Accounts::User.onboard(user)
    end

    finish_sign_up
  end

  def edit
    raise ActionController::RoutingError.new("Page unavailable.")
  end

  protected

  def after_sign_in_path_for(resource)
    if request.path == new_user_registration_path && params["invite_token"].present?
      flash[:alert] = t("invitation.flash.already_signed_in.new_user", email: current_user.email)
    end

    super
  end

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
      respond_with(user, location: after_sign_up_path_for(user))
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
