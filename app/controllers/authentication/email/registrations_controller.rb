class Authentication::Email::RegistrationsController < Devise::RegistrationsController
  include Exceptionable
  include Authenticatable

  before_action :skip_authentication, only: [:new, :create]
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]

  def new
    if @token.present?
      flash[:notice] = t("invitation.flash.signup_before", org: @invite.organization.name)
    end

    super do |email_auth|
      @user = email_auth.build_user
      @organization = @user.organizations.build
      @email_authentication.email = @invite&.email
    end
  end

  def edit
    raise ActionController::RoutingError.new("Page unavailable.")
  end

  def create
    if @token.present?
      build_resource(sign_up_params_for_invites)

      if sign_up_email != @invite.email
        flash.clear
        flash[:notice] = t("invitation.flash.invite_error.email")
        render :new, status: :unprocessable_entity and return
      end

      resource.add(@invite)
    else
      build_resource(sign_up_params)
      Accounts::User.onboard_via_email(resource)
    end

    finish_signing_up
    identify_team
  end

  protected

  def after_sign_in_path_for(resource)
    if request.path == new_email_authentication_registration_path && params["invite_token"].present?
      flash[:alert] = t("invitation.flash.already_signed_in.new_user", email: current_email_authentication.email)
    end

    super
  end

  def finish_signing_up
    if resource.persisted?
      if resource.active_for_authentication?
        set_flash_message!(:notice, :signed_up)
        sign_up(resource_name, resource)
        respond_with(resource, location: after_sign_up_path_for(resource))
      else
        set_flash_message!(:notice, :"signed_up_but_#{resource.inactive_message}")
        expire_data_after_sign_in!
        respond_with(resource, location: after_inactive_sign_up_path_for(resource))
      end
    else
      clean_up_passwords(resource)
      set_minimum_password_length
      render :new, status: :unprocessable_entity
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
        :email,
        :password,
        :password_confirmation,
        user_attributes: [
          :full_name,
          :preferred_name,
          organizations_attributes: [:name]
        ]
      )
    end
  end

  def sign_up_params_for_invites
    sign_up_params.except(:organizations_attributes)
  end

  def sign_up_email
    sign_up_params[:email].downcase
  end

  def identify_team
    return unless resource.persisted?

    tracking_org = resource.organization
    SiteAnalytics.identify_and_group(resource, tracking_org)
    SiteAnalytics.track(resource, tracking_org, DeviceDetector.new(request.user_agent), "Signup")
  end
end
