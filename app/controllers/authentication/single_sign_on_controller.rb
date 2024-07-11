class Authentication::SingleSignOnController < ApplicationController

  def handle
    code = params[:code]
    jwt_response = client.saml_exchange_token(code)
    session_token = jwt_response[Descope::Mixins::Common::SESSION_TOKEN_NAME].fetch("jwt")
    refresh_token = jwt_response[Descope::Mixins::Common::REFRESH_SESSION_TOKEN_NAME].fetch('jwt')

    @jwt_response = client.validate_and_refresh_session(session_token:, refresh_token:)
    @user_id = @jwt_response["sub"]
    @user_data = client.load_by_user_id(@user_id)
    # validate: database lookup

    cookies[:sso_session_token] = session_token
    cookies[:sso_refresh_token] = refresh_token
  end

  def login
    info = client.saml_sign_in(
      tenant: ENV["DESCOPE_TENANT_ID"],
      redirect_url: ENV["DESCOPE_REDIRECT_URL"]
    )

    Rails.logger.info("SAML Sign In Info: #{info}")
    redirect_to info["url"], allow_other_host: true
  end

  def client
    Rails.application.config.descope_client
  end
end

#
# tramline organization (domain, name, domains, configuration_link, protocol) ==> tenant descope
# find tramline organization on email check frontend => lookup tenant and do the login flow above or throw an error
# user returns to "handle"
# we get user data + tokens
#
