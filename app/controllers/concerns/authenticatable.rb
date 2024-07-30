module Authenticatable
  SSO_JWT_SESSION_KEY = :sso_session
  SSO_JWT_REFRESH_KEY = :sso_refresh
  SSO_JWT_USER_ID_KEY = :sso_user_id

  def skip_authentication
    if login_by_sso?
      authenticate_sso_request!
      redirect_to after_sign_in_path_for(:user) if current_user
      return
    end

    if email_authentication_signed_in?
      redirect_to after_sign_in_path_for(:user)
    end
  end

  def authenticate_sso_request!
    return unless login_by_sso?

    st, rt = session[SSO_JWT_SESSION_KEY], session[SSO_JWT_REFRESH_KEY]
    result = Accounts::SsoAuthentication.validate_or_refresh_session(st, rt)

    if result.ok?
      result.value! => { user_email: }
      if (user = Accounts::User.find_via_sso_email(user_email))
        @current_sso_user = user
        set_sso_jwt_in_session(result.value!)
      end
    else
      clear_sso_jwt_in_session
    end
  end

  def login_by_sso?
    (session[SSO_JWT_SESSION_KEY].present? || session[SSO_JWT_REFRESH_KEY].present?) &&
      session[SSO_JWT_USER_ID_KEY].present?
  end

  def set_sso_jwt_in_session(params)
    session[SSO_JWT_SESSION_KEY] = params[:session_token]
    session[SSO_JWT_USER_ID_KEY] = params[:user_email]
    session[SSO_JWT_REFRESH_KEY] = params[:refresh_token] if params[:refresh_token].present?
  end

  def clear_sso_jwt_in_session
    session[SSO_JWT_SESSION_KEY] = nil
    session[SSO_JWT_REFRESH_KEY] = nil
    session[SSO_JWT_USER_ID_KEY] = nil
  end
end
