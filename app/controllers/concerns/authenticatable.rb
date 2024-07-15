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

    # TODO: path where user has externally logged out, log them out of here as well

    if result.ok?
      result.value! => { user_email: }
      if (user = Accounts::User.find_via_sso_email(user_email))
        @current_sso_user = user
        set_sso_jwt_in_session(**result.value!)
      end
    end
  end

  def login_by_sso?
    (session[SSO_JWT_SESSION_KEY].present? || session[SSO_JWT_REFRESH_KEY].present?) &&
      session[SSO_JWT_USER_ID_KEY].present?
  end

  def set_sso_jwt_in_session(session_token:, refresh_token:, user_email:)
    session[SSO_JWT_SESSION_KEY] = session_token
    session[SSO_JWT_REFRESH_KEY] = refresh_token
    session[SSO_JWT_USER_ID_KEY] = user_email
  end

  def clear_sso_jwt_in_session
    session[SSO_JWT_SESSION_KEY] = nil
    session[SSO_JWT_REFRESH_KEY] = nil
    session[SSO_JWT_USER_ID_KEY] = nil
  end
end
