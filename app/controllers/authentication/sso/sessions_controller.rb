class Authentication::Sso::SessionsController < ApplicationController
  include Authenticatable

  before_action :skip_authentication, only: [:new, :create]
  after_action :prepare_intercom_shutdown, only: [:destroy]
  after_action :intercom_shutdown, only: [:new]

  def new
    set_invite
    @resource = Accounts::SsoAuthentication.new
  end

  def create
    if (result = Accounts::User.start_sign_in_via_sso(sso_authentication_params[:email]))
      redirect_url = result["url"]
      if redirect_url&.match?(URI::DEFAULT_PARSER.make_regexp)
        redirect_to URI.parse(redirect_url).to_s, allow_other_host: true
      else
        redirect_to sso_new_sso_session_path, flash: {error: t(".connect_failure")}
      end
    else
      redirect_to sso_new_sso_session_path, flash: {error: t(".no_account")}
    end
  rescue Accounts::SsoAuthentication::AuthException
    redirect_to sso_new_sso_session_path, flash: {error: t(".failure")}
  end

  def saml_redeem
    if saml_callback_code.blank?
      redirect_to root_path
      return
    end

    if (auth_data = Accounts::User.finish_sign_in_via_sso(saml_callback_code, request.remote_ip))
      set_sso_jwt_in_session(auth_data)
      authenticate_sso_request!
      track_login
      redirect_to after_sign_in_path_for(:user), notice: t("devise.sessions.signed_in")
      return
    end

    redirect_to sso_new_sso_session_path, flash: {error: t(".failure")}
  end

  def destroy
    logout_sso
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

  def prepare_intercom_shutdown
    IntercomRails::ShutdownHelper.prepare_intercom_shutdown(session)
  end

  def intercom_shutdown
    IntercomRails::ShutdownHelper.intercom_shutdown(session, cookies, request.domain)
  end

  def track_login
    SiteAnalytics.track(current_user, current_organization, device, "Login", {sso: true})
  end
end
