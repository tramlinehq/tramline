# == Schema Information
#
# Table name: sso_authentications
#
#  id               :uuid             not null, primary key
#  email            :string           default(""), not null, indexed
#  logout_time      :datetime
#  sso_created_time :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  login_id         :string           not null, indexed
#
class Accounts::SsoAuthentication < ApplicationRecord
  include Linkable

  has_one :user_authentication, as: :authenticatable, dependent: :destroy
  has_one :user, through: :user_authentication

  class << self
    def start_sign_in(tenant)
      client.saml_sign_in(tenant: tenant, redirect_url:)
    end

    def finish_sign_in(code)
      client
        .saml_exchange_token(code)
        .then { |jwt| parse_jwt(jwt) }
        .then { |tokens| validate_or_refresh_session(tokens[:session_token], tokens[:refresh_token]) }
    end

    def validate_or_refresh_session(session_token, refresh_token)
      GitHub::Result.new { parse_jwt(client.validate_and_refresh_session(session_token:, refresh_token:)) }
    rescue => e
      Rails.logger.error(e)
      GitHub::Result.new { e }
    end

    def parse_jwt(jwt)
      session = jwt[Descope::Mixins::Common::SESSION_TOKEN_NAME]
      refresh = jwt[Descope::Mixins::Common::REFRESH_SESSION_TOKEN_NAME]
      session_token = session&.fetch("jwt", nil)
      refresh_token = refresh&.fetch("jwt", nil)
      user_email = session&.fetch("email", nil) || refresh&.fetch("email", nil)

      {
        session_token:, refresh_token:, user_email:
      }
    end

    def client
      Rails.application.config.descope_client
    end

    def redirect_url
      return if Rails.env.test?
      sso_handle_saml_url(link_params(port: nil))
    end
  end
end
