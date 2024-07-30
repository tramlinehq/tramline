class Authentication::Sso::SessionsController < ApplicationController
  include Authenticatable

  before_action :skip_authentication, only: [:new, :create]
  after_action :prepare_intercom_shutdown, only: [:destroy]
  after_action :intercom_shutdown, only: [:new]
  after_action :track_login, only: [:create]

  def new
    set_invite
    @resource = Accounts::SsoAuthentication.new
  end

  def create
    if (result = Accounts::User.start_sign_in_via_sso(sso_authentication_params[:email]))
      redirect_to result["url"], allow_other_host: true
    else
      redirect_to sso_new_sso_session_path, flash: {error: "No Single Sign-On account found!"}
    end
  end

  def saml_redeem
    if saml_callback_code.blank?
      redirect_to root_path
      return
    end

    if (auth_data = Accounts::User.finish_sign_in_via_sso(saml_callback_code))
      set_sso_jwt_in_session(auth_data)
      redirect_to after_sign_in_path_for(:user), notice: t("devise.sessions.signed_in")
      return
    end

    redirect_to sso_new_sso_session_path, flash: {error: "Single Sign-On login failed!"}
  end

  def destroy
    clear_sso_jwt_in_session
    redirect_to sso_new_sso_session_path, notice: t("devise.sessions.signed_out")
  end

  protected

  def sso_authentication_params
    params.require(:sso_authentication).permit(:email)
  end

  def saml_callback_code
    params[:code]
  end

  def set_invite
    invite_token = params[:invite_token]
    @invite = Accounts::Invite.find_by(token: invite_token) if invite_token.present?
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end

  def prepare_intercom_shutdown
    IntercomRails::ShutdownHelper.prepare_intercom_shutdown(session)
  end

  def intercom_shutdown
    IntercomRails::ShutdownHelper.intercom_shutdown(session, cookies, request.domain)
  end

  def track_login
    SiteAnalytics.track(current_user, current_organization, device, "Login")
  end
end
