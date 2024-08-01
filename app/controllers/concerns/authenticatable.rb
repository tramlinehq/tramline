module Authenticatable
  SSO_JWT_SESSION_KEY = :sso_session
  SSO_JWT_REFRESH_KEY = :sso_refresh
  SSO_JWT_USER_ID_KEY = :sso_user_id

  def skip_authentication
    if sso_authentication_signed_in? || email_authentication_signed_in?
      redirect_to after_sign_in_path_for(:user)
    end
  end

  def authenticate_sso_request!
    return unless sso_authentication_signed_in?

    st, rt = session[SSO_JWT_SESSION_KEY], session[SSO_JWT_REFRESH_KEY]
    result = Accounts::SsoAuthentication.validate_or_refresh_session(st, rt)

    if result.ok?
      auth_data = result.value!
      auth_data => { user_email: }
      if (user = Accounts::User.find_via_sso_email(user_email))
        @current_sso_user = user
        set_sso_jwt_in_session(auth_data)
      end
    else
      clear_sso_jwt_in_session
    end
  end

  def sso_authentication_signed_in?
    (session[SSO_JWT_SESSION_KEY].present? || session[SSO_JWT_REFRESH_KEY].present?) &&
      session[SSO_JWT_USER_ID_KEY].present?
  end

  def set_sso_jwt_in_session(params)
    session[SSO_JWT_SESSION_KEY] = params[:session_token]
    session[SSO_JWT_USER_ID_KEY] = params[:user_email]
    session[SSO_JWT_REFRESH_KEY] = params[:refresh_token] if params[:refresh_token].present?
  end

  def logout_sso
    rt = session[SSO_JWT_REFRESH_KEY]
    Accounts::SsoAuthentication.logout(rt) if rt.present?
  end

  def clear_sso_jwt_in_session
    session[SSO_JWT_SESSION_KEY] = nil
    session[SSO_JWT_REFRESH_KEY] = nil
    session[SSO_JWT_USER_ID_KEY] = nil
  end
end
